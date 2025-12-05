#!/bin/bash

# ============================================================================
# Update Keycloak and RHDH Configuration Script
# ============================================================================
# This script updates the cluster-specific URLs in the Gitea repository:
# - ArgoCD Application repository URLs (from playground-config ConfigMap)
# - Developer Hub and Keycloak configurations
# - OAuth client redirect URIs
#
# Prerequisites:
# - oc CLI installed and logged in
# - playground-config ConfigMap created in openshift-gitops namespace
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
# GET BASE URL FROM CONFIGMAP AND CONSTRUCT URLS
# ============================================================================

get_route_urls() {
    print_header "Getting Cluster Configuration"

    # Get BASE_URL from playground-config ConfigMap
    print_info "Reading BASE_URL from playground-config ConfigMap..."
    BASE_URL=$(oc get configmap playground-config -n openshift-gitops -o jsonpath='{.data.BASE_URL}' 2>/dev/null || echo "")

    if [ -z "$BASE_URL" ]; then
        print_error "Could not find playground-config ConfigMap in openshift-gitops namespace"
        print_info "Make sure the initial setup has been completed"
        print_info "Run: assets/0_initial_setup/install.sh"
        exit 1
    fi

    print_success "Base URL from ConfigMap: ${BASE_URL}"

    # Construct service URLs from BASE_URL
    # Format: https://<route-name>.<namespace>.<BASE_URL>
    RHDH_BASE_URL="https://backstage-developer-hub-rhdh.${BASE_URL}"
    KEYCLOAK_BASE_URL="https://keycloak-keycloak.${BASE_URL}"

    print_info "Constructed Developer Hub URL: ${RHDH_BASE_URL}"
    print_info "Constructed Keycloak URL: ${KEYCLOAK_BASE_URL}"

    # Get OpenShift API URL (this remains dynamic as it's not route-based)
    print_info "Getting OpenShift API URL..."
    OPENSHIFT_API_URL=$(oc whoami --show-server 2>/dev/null || echo "")

    if [ -z "$OPENSHIFT_API_URL" ]; then
        print_error "Could not get OpenShift API URL"
        exit 1
    fi

    print_success "OpenShift API URL: ${OPENSHIFT_API_URL}"
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

    # Construct Gitea route from BASE_URL
    GITEA_ROUTE="gitea-gitea.${BASE_URL}"
    print_info "Gitea route: ${GITEA_ROUTE}"

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

    # Update ArgoCD Application repository URLs
    print_info "Updating ArgoCD Application repository URLs..."
    TARGET_REPO_URL="https://${GITEA_ROUTE}/admin/playground-gitops.git"

    # Find and update all ArgoCD Application YAML files
    ARGOCD_APP_FILES=$(find . -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \) ! -path "*/test/*" 2>/dev/null)

    if [ -n "$ARGOCD_APP_FILES" ]; then
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                # Replace any existing repoURL with the correct one from BASE_URL
                sed -i.bak "s|repoURL: https://[^/]*/[^/]*/playground-gitops\.git|repoURL: ${TARGET_REPO_URL}|g" "$file"
                sed -i.bak "s|repoURL: [^/]*\.apps\.[^/]*/admin/playground-gitops\.git|repoURL: ${TARGET_REPO_URL}|g" "$file"
                rm -f "${file}.bak"
            fi
        done <<< "$ARGOCD_APP_FILES"
        print_success "Updated ArgoCD Application repository URLs to ${TARGET_REPO_URL}"
    fi

    # Update Developer Hub secrets
    print_info "Updating Developer Hub secrets..."
    if [ -f "developerhub/manifests/06-secrets.yaml" ]; then
        # Replace route placeholders with actual URLs
        sed -i.bak "s|https://KEYCLOAK_ROUTE|${KEYCLOAK_BASE_URL}|g" developerhub/manifests/06-secrets.yaml
        sed -i.bak "s|https://RHDH_ROUTE|${RHDH_BASE_URL}|g" developerhub/manifests/06-secrets.yaml
        sed -i.bak "s|https://OPENSHIFT_API_URL|${OPENSHIFT_API_URL}|g" developerhub/manifests/06-secrets.yaml
        sed -i.bak "s|rhdh-client-secret-change-in-production|${KEYCLOAK_CLIENT_SECRET}|g" developerhub/manifests/06-secrets.yaml
        rm -f developerhub/manifests/06-secrets.yaml.bak
        print_success "Updated secrets with Keycloak, RHDH, and OpenShift URLs"
    fi

    # Update Keycloak realm import
    print_info "Updating Keycloak realm import..."
    if [ -f "keycloak/manifests/05-realm-import-rhdh.yaml" ]; then
        # Replace RHDH_BASE_URL placeholder in redirect URIs
        sed -i.bak "s|RHDH_BASE_URL|${RHDH_BASE_URL}|g" keycloak/manifests/05-realm-import-rhdh.yaml
        rm -f keycloak/manifests/05-realm-import-rhdh.yaml.bak
        print_success "Updated realm import with RHDH URL"
    fi

    # Update OpenShift OAuth client
    print_info "Updating OpenShift OAuth client..."
    if [ -f "developerhub/manifests/11-oauth-client.yaml" ]; then
        # Replace RHDH_BASE_URL placeholder in redirect URIs
        sed -i.bak "s|RHDH_BASE_URL|${RHDH_BASE_URL}|g" developerhub/manifests/11-oauth-client.yaml
        rm -f developerhub/manifests/11-oauth-client.yaml.bak
        print_success "Updated OAuth client with RHDH URL"
    fi

    # Commit and push changes
    print_info "Committing and pushing changes to Gitea..."
    git config user.name "GitOps Admin"
    git config user.email "gitops@example.com"

    git add .
    git commit -m "Update ArgoCD apps, Keycloak and RHDH configuration with cluster routes from ConfigMap" || {
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

    echo "Updated URLs (from ConfigMap BASE_URL: ${BASE_URL}):"
    echo "  Gitea Repository:  https://${GITEA_ROUTE}/admin/playground-gitops"
    echo "  Developer Hub:     ${RHDH_BASE_URL}"
    echo "  Keycloak:          ${KEYCLOAK_BASE_URL}"
    echo ""
    echo "Updated manifests in Gitea:"
    echo "  ✓ ArgoCD Application repository URLs (playground-apps.yaml, apps/*.yaml)"
    echo "  ✓ Developer Hub secrets (Keycloak, RHDH, OpenShift API URLs)"
    echo "  ✓ Keycloak realm import (RHDH redirect URIs)"
    echo "  ✓ OpenShift OAuth client (RHDH redirect URIs)"
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
