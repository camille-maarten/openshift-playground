#!/bin/bash

# ============================================================================
# Update Keycloak and RHDH Configuration Script
# ============================================================================
# This script updates the Developer Hub and Keycloak configurations with
# actual cluster routes after deployment.
#
# Prerequisites:
# - oc CLI installed and logged in
# - Keycloak deployed and route available
# - Developer Hub deployed and route available
# - Gitea repository with playground-gitops
#
# Usage:
#   ./update-keycloak-rhdh-config.sh
# ============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check for oc
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI is not installed"
        exit 1
    fi

    # Check if logged in
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift. Please run 'oc login' first"
        exit 1
    fi

    print_info "Logged in as: $(oc whoami)"
    print_success "Prerequisites check passed"
}

# ============================================================================
# GET ROUTE URLS
# ============================================================================

get_route_urls() {
    print_header "Getting Cluster Routes"

    # Get RHDH route
    print_info "Getting Developer Hub route..."
    RHDH_ROUTE=$(oc get route backstage-developer-hub -n rhdh -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -z "$RHDH_ROUTE" ]; then
        print_error "Could not find Developer Hub route in namespace rhdh"
        print_info "Make sure Developer Hub is deployed"
        exit 1
    fi

    RHDH_BASE_URL="https://${RHDH_ROUTE}"
    print_success "Developer Hub URL: ${RHDH_BASE_URL}"

    # Get Keycloak route - try different route names
    print_info "Getting Keycloak route..."
    KEYCLOAK_ROUTE=$(oc get route -n keycloak -o jsonpath='{.items[?(@.spec.port.targetPort=="https")].spec.host}' 2>/dev/null | awk '{print $1}' || echo "")

    if [ -z "$KEYCLOAK_ROUTE" ]; then
        # Try to get any route in keycloak namespace
        KEYCLOAK_ROUTE=$(oc get route -n keycloak -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
    fi

    if [ -z "$KEYCLOAK_ROUTE" ]; then
        print_error "Could not find Keycloak route in namespace keycloak"
        print_info "Make sure Keycloak is deployed"
        exit 1
    fi

    KEYCLOAK_BASE_URL="https://${KEYCLOAK_ROUTE}"
    print_success "Keycloak URL: ${KEYCLOAK_BASE_URL}"
}

# ============================================================================
# GET KEYCLOAK CLIENT SECRET
# ============================================================================

get_keycloak_client_secret() {
    print_header "Getting Keycloak Client Secret"

    # Wait for KeycloakRealmImport to be processed
    print_info "Waiting for Keycloak realm to be ready..."
    sleep 10

    # Try to get the client secret from Keycloak
    # The RHBK operator creates a secret with the client credentials
    SECRET_NAME="keycloak-client-secret-rhdh"

    # Check if secret exists
    if oc get secret "${SECRET_NAME}" -n keycloak &> /dev/null; then
        KEYCLOAK_CLIENT_SECRET=$(oc get secret "${SECRET_NAME}" -n keycloak -o jsonpath='{.data.CLIENT_SECRET}' 2>/dev/null | base64 -d || echo "")
    fi

    # If not found, try alternate secret name
    if [ -z "$KEYCLOAK_CLIENT_SECRET" ]; then
        SECRET_NAME="kc-client-secret-rhdh"
        if oc get secret "${SECRET_NAME}" -n keycloak &> /dev/null; then
            KEYCLOAK_CLIENT_SECRET=$(oc get secret "${SECRET_NAME}" -n keycloak -o jsonpath='{.data.clientSecret}' 2>/dev/null | base64 -d || echo "")
        fi
    fi

    # If still not found, generate a random one
    if [ -z "$KEYCLOAK_CLIENT_SECRET" ]; then
        print_warning "Could not find Keycloak client secret, generating new one"
        KEYCLOAK_CLIENT_SECRET=$(openssl rand -base64 32)
        print_info "Generated client secret (save this for manual configuration if needed)"
    else
        print_success "Found Keycloak client secret"
    fi
}

# ============================================================================
# UPDATE GITEA REPOSITORY
# ============================================================================

update_gitea_repository() {
    print_header "Updating Gitea Repository"

    # Get Gitea route
    GITEA_ROUTE=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -z "$GITEA_ROUTE" ]; then
        print_error "Could not find Gitea route"
        exit 1
    fi

    # Determine script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Create temporary directory for repository
    TMP_DIR=$(mktemp -d)
    trap "rm -rf ${TMP_DIR}" EXIT

    print_info "Cloning Gitea repository..."
    cd "${TMP_DIR}"

    # Clone the repository (using https)
    git clone "https://${GITEA_ROUTE}/admin/playground-gitops.git" || {
        print_error "Failed to clone repository"
        print_info "You may need to configure git credentials for Gitea"
        exit 1
    }

    cd playground-gitops

    # Update Developer Hub secrets
    print_info "Updating Developer Hub secrets..."
    if [ -f "developerhub/manifests/06-secrets.yaml" ]; then
        # Replace route placeholders with actual URLs
        sed -i.bak "s|https://KEYCLOAK_ROUTE|${KEYCLOAK_BASE_URL}|g" developerhub/manifests/06-secrets.yaml
        sed -i.bak "s|https://RHDH_ROUTE|${RHDH_BASE_URL}|g" developerhub/manifests/06-secrets.yaml
        sed -i.bak "s|rhdh-client-secret-change-in-production|${KEYCLOAK_CLIENT_SECRET}|g" developerhub/manifests/06-secrets.yaml
        rm -f developerhub/manifests/06-secrets.yaml.bak
        print_success "Updated secrets with Keycloak and RHDH URLs"
    fi

    # Update Keycloak realm import
    print_info "Updating Keycloak realm import..."
    if [ -f "keycloak/manifests/05-realm-import-rhdh.yaml" ]; then
        # Replace RHDH_BASE_URL placeholder in redirect URIs
        sed -i.bak "s|RHDH_BASE_URL|${RHDH_BASE_URL}|g" keycloak/manifests/05-realm-import-rhdh.yaml
        rm -f keycloak/manifests/05-realm-import-rhdh.yaml.bak
        print_success "Updated realm import with RHDH URL"
    fi

    # Commit and push changes
    print_info "Committing and pushing changes to Gitea..."
    git config user.name "GitOps Admin"
    git config user.email "gitops@example.com"

    git add .
    git commit -m "Update Keycloak and RHDH configuration with cluster routes" || {
        print_warning "No changes to commit"
        return 0
    }

    git push || {
        print_error "Failed to push changes to Gitea"
        print_info "You may need to configure git credentials"
        exit 1
    }

    print_success "Changes pushed to Gitea repository"
}

# ============================================================================
# SYNC ARGOCD APPLICATIONS
# ============================================================================

sync_argocd_apps() {
    print_header "Syncing ArgoCD Applications"

    print_info "Triggering ArgoCD sync for Developer Hub..."
    oc patch application developer-hub -n openshift-gitops --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' 2>/dev/null || true

    print_info "Triggering ArgoCD sync for Keycloak..."
    oc patch application keycloak -n openshift-gitops --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"normal"}}}' 2>/dev/null || true

    print_success "ArgoCD sync triggered - changes will be applied shortly"
}

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

display_summary() {
    print_header "Configuration Summary"

    echo "Updated URLs:"
    echo "  Developer Hub: ${RHDH_BASE_URL}"
    echo "  Keycloak:      ${KEYCLOAK_BASE_URL}"
    echo ""
    echo "Keycloak Admin Console:"
    echo "  URL: ${KEYCLOAK_BASE_URL}/admin"
    echo "  Username: admin"
    echo "  Password: (get with: oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)"
    echo ""
    echo "Developer Hub Login:"
    echo "  URL: ${RHDH_BASE_URL}"
    echo "  Test User: pe-user"
    echo "  Password: rhdh1234!"
    echo ""
    echo "Next Steps:"
    echo "  1. Wait for ArgoCD to sync the applications"
    echo "  2. Access Developer Hub and click 'Sign In'"
    echo "  3. You should be redirected to Keycloak for authentication"
    echo "  4. Log in with pe-user / rhdh1234!"
    echo ""

    print_success "Configuration update complete!"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "Keycloak and RHDH Configuration Update"

    check_prerequisites
    get_route_urls
    get_keycloak_client_secret
    update_gitea_repository
    sync_argocd_apps
    display_summary
}

# Run main function
main
