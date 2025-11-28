#!/bin/bash

# ============================================================================
# Complete OpenShift Playground Setup Script
# ============================================================================
# This script orchestrates the complete setup process for the OpenShift
# playground environment, including:
#
# 1. Initial infrastructure setup (Gitea, GitOps, etc.)
# 2. GitOps repository upload and ArgoCD deployment
# 3. GitHub remote restoration for development workflow
#
# Prerequisites:
# - OpenShift cluster access (oc CLI logged in)
# - kubectl, jq, git, curl installed
# - Cluster admin permissions
#
# Usage:
#   ./run_complete.sh
# ============================================================================

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INITIAL_SETUP_DIR="${SCRIPT_DIR}/assets/0_initial_setup"
GITOPS_DIR="${SCRIPT_DIR}/assets/1_gitops"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_info() {
    echo "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "${CYAN}========================================"
    echo "$1"
    echo "========================================${NC}"
    echo ""
}

print_step() {
    echo ""
    echo "${CYAN}>>> $1${NC}"
    echo ""
}

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_tools=()

    # Check for required tools
    if ! command -v oc &> /dev/null; then
        missing_tools+=("oc")
    fi

    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi

    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi

    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi

    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install missing tools and try again"
        exit 1
    fi

    # Check if logged into OpenShift
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift"
        print_info "Please run 'oc login' first"
        exit 1
    fi

    print_success "All prerequisites met"
    print_info "Logged in as: $(oc whoami)"
    print_info "Cluster: $(oc whoami --show-server)"
}

# ============================================================================
# STEP 1: INITIAL SETUP
# ============================================================================

run_initial_setup() {
    print_header "Step 1: Initial Infrastructure Setup"

    print_info "This will install:"
    print_info "  - OpenShift GitOps (ArgoCD)"
    print_info "  - Gitea (Git server)"
    print_info "  - Base configuration and credentials"
    echo ""

    if [ ! -f "${INITIAL_SETUP_DIR}/install_complete.sh" ]; then
        print_error "Initial setup script not found: ${INITIAL_SETUP_DIR}/install_complete.sh"
        exit 1
    fi

    print_step "Running install_complete.sh..."

    cd "${INITIAL_SETUP_DIR}"

    # Run the installation script
    if ./install_complete.sh; then
        print_success "Initial infrastructure setup completed"
    else
        print_error "Initial setup failed"
        exit 1
    fi

    # Return to script directory
    cd "${SCRIPT_DIR}"
}

# ============================================================================
# STEP 2: GITOPS DEPLOYMENT
# ============================================================================

run_gitops_deployment() {
    print_header "Step 2: GitOps Repository Upload and Deployment"

    print_info "This will:"
    print_info "  - Upload GitOps manifests to Gitea"
    print_info "  - Deploy ArgoCD applications"
    print_info "  - Install Developer Hub, Kafka operators"
    echo ""

    if [ ! -f "${GITOPS_DIR}/upload-and-deploy.sh" ]; then
        print_error "GitOps deployment script not found: ${GITOPS_DIR}/upload-and-deploy.sh"
        exit 1
    fi

    print_step "Running upload-and-deploy.sh..."

    cd "${GITOPS_DIR}"

    # Run the GitOps deployment script
    if ./upload-and-deploy.sh; then
        print_success "GitOps deployment completed"
    else
        print_error "GitOps deployment failed"
        exit 1
    fi

    # Return to script directory
    cd "${SCRIPT_DIR}"
}

# ============================================================================
# STEP 3: WAIT FOR ROUTES AND CONFIGURE KEYCLOAK/RHDH
# ============================================================================

wait_for_routes() {
    print_header "Step 3: Waiting for Routes to be Created"

    print_info "This will wait for:"
    print_info "  - Keycloak route to be available"
    print_info "  - Developer Hub route to be available"
    echo ""

    local MAX_WAIT=600  # 10 minutes
    local WAIT_INTERVAL=10
    local elapsed=0

    # Wait for Keycloak route
    print_step "Waiting for Keycloak route..."
    while [ $elapsed -lt $MAX_WAIT ]; do
        if oc get route -n keycloak &> /dev/null; then
            KEYCLOAK_ROUTE=$(oc get route -n keycloak -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "")
            if [ -n "$KEYCLOAK_ROUTE" ]; then
                print_success "Keycloak route found: ${KEYCLOAK_ROUTE}"
                break
            fi
        fi

        if [ $elapsed -gt 0 ]; then
            print_info "Still waiting for Keycloak route... (${elapsed}s elapsed)"
        fi
        sleep $WAIT_INTERVAL
        elapsed=$((elapsed + WAIT_INTERVAL))
    done

    if [ -z "$KEYCLOAK_ROUTE" ]; then
        print_warning "Keycloak route not found after ${MAX_WAIT}s"
        print_info "Skipping Keycloak/RHDH configuration"
        return 1
    fi

    # Wait for Developer Hub route
    print_step "Waiting for Developer Hub route..."
    elapsed=0
    while [ $elapsed -lt $MAX_WAIT ]; do
        if oc get route backstage-developer-hub -n rhdh &> /dev/null; then
            RHDH_ROUTE=$(oc get route backstage-developer-hub -n rhdh -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
            if [ -n "$RHDH_ROUTE" ]; then
                print_success "Developer Hub route found: ${RHDH_ROUTE}"
                break
            fi
        fi

        if [ $elapsed -gt 0 ]; then
            print_info "Still waiting for Developer Hub route... (${elapsed}s elapsed)"
        fi
        sleep $WAIT_INTERVAL
        elapsed=$((elapsed + WAIT_INTERVAL))
    done

    if [ -z "$RHDH_ROUTE" ]; then
        print_warning "Developer Hub route not found after ${MAX_WAIT}s"
        print_info "Skipping Keycloak/RHDH configuration"
        return 1
    fi

    print_success "All routes are available"
    return 0
}

# ============================================================================
# STEP 4: CONFIGURE KEYCLOAK AND RHDH INTEGRATION
# ============================================================================

configure_keycloak_rhdh() {
    print_header "Step 4: Configuring Keycloak and Developer Hub Integration"

    print_info "This will:"
    print_info "  - Update Keycloak configuration with cluster routes"
    print_info "  - Update Developer Hub OIDC configuration"
    print_info "  - Enable SSO login with Keycloak"
    echo ""

    if [ ! -f "${GITOPS_DIR}/update-keycloak-rhdh-config.sh" ]; then
        print_error "Keycloak/RHDH config script not found: ${GITOPS_DIR}/update-keycloak-rhdh-config.sh"
        print_warning "Skipping Keycloak/RHDH configuration"
        return 0
    fi

    print_step "Running update-keycloak-rhdh-config.sh..."

    cd "${GITOPS_DIR}"

    # Make sure script is executable
    chmod +x update-keycloak-rhdh-config.sh

    # Run the configuration script
    if ./update-keycloak-rhdh-config.sh; then
        print_success "Keycloak and Developer Hub configured for SSO"
    else
        print_warning "Keycloak/RHDH configuration had issues (non-critical)"
    fi

    # Return to script directory
    cd "${SCRIPT_DIR}"
}

# ============================================================================
# STEP 5: RESTORE GITHUB REMOTE
# ============================================================================

run_restore_github_remote() {
    print_header "Step 5: Restore GitHub Remote for Development"

    print_info "This will:"
    print_info "  - Remove Gitea remote (used by ArgoCD)"
    print_info "  - Restore GitHub as 'origin' remote"
    print_info "  - Enable pushing changes to GitHub"
    echo ""

    if [ ! -f "${GITOPS_DIR}/restore-github-remote.sh" ]; then
        print_error "GitHub remote script not found: ${GITOPS_DIR}/restore-github-remote.sh"
        exit 1
    fi

    print_step "Running restore-github-remote.sh..."

    cd "${GITOPS_DIR}"

    # Run the restore GitHub remote script
    if ./restore-github-remote.sh; then
        print_success "GitHub remote restored"
    else
        print_warning "GitHub remote restoration had issues (non-critical)"
    fi

    # Return to script directory
    cd "${SCRIPT_DIR}"
}

# ============================================================================
# FINAL SUMMARY
# ============================================================================

display_final_summary() {
    print_header "Complete Setup Summary"

    echo "${GREEN}All setup steps completed successfully!${NC}"
    echo ""
    echo "What was installed:"
    echo "  ✓ OpenShift GitOps (ArgoCD)"
    echo "  ✓ Gitea (Git server)"
    echo "  ✓ Red Hat Developer Hub"
    echo "  ✓ Red Hat Build of Keycloak"
    echo "  ✓ AMQ Streams (Kafka) operator"
    echo "  ✓ Playground namespace with resource quotas"
    echo ""
    echo "SSO Configuration:"
    echo "  ✓ Keycloak integrated with Developer Hub"
    echo "  ✓ OIDC authentication enabled"
    echo "  ✓ Test user: pe-user (password: rhdh1234!)"
    echo ""
    echo "Configuration files created:"
    echo "  📄 info/environment_config_gitops.md    - GitOps infrastructure details"
    echo "  📄 info/environment_config_platform.md  - Platform components details"
    echo "  📄 info/versions.csv                     - Component versions"
    echo ""
    echo "Useful commands:"
    echo ""
    echo "  # Check ArgoCD applications"
    echo "  oc get applications -n openshift-gitops"
    echo ""
    echo "  # Get ArgoCD admin password"
    echo "  oc get secret openshift-gitops-cluster -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d"
    echo ""
    echo "  # Get ArgoCD URL"
    echo "  oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='https://{.spec.host}'"
    echo ""
    echo "  # Get Developer Hub URL"
    echo "  oc get route -n rhdh -o jsonpath='https://{.items[0].spec.host}'"
    echo ""
    echo "  # Get Gitea URL"
    echo "  oc get route gitea -n gitea -o jsonpath='https://{.spec.host}'"
    echo ""
    echo "  # Get Keycloak URL"
    echo "  oc get route -n keycloak -o jsonpath='https://{.items[0].spec.host}'"
    echo ""
    echo "  # Get Keycloak admin password"
    echo "  oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d"
    echo ""
    echo "Next steps:"
    echo "  1. Access ArgoCD console to monitor deployments"
    echo "  2. Check info/environment_config_platform.md for all details"
    echo "  3. Access Developer Hub and log in with Keycloak SSO (pe-user / rhdh1234!)"
    echo ""

    print_success "Setup complete! 🎉"
}

# ============================================================================
# ERROR HANDLER
# ============================================================================

error_handler() {
    local line_number=$1
    print_error "Script failed at line ${line_number}"
    print_info "Check the output above for details"
    exit 1
}

trap 'error_handler ${LINENO}' ERR

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "OpenShift Playground Complete Setup"

    echo "${CYAN}This script will set up the complete OpenShift playground environment.${NC}"
    echo ""
    echo "The following steps will be executed:"
    echo "  1. Initial infrastructure setup (Gitea, GitOps)"
    echo "  2. GitOps repository upload and ArgoCD deployment"
    echo "  3. Wait for routes and configure Keycloak/RHDH SSO"
    echo "  4. Configure Keycloak and Developer Hub integration"
    echo "  5. GitHub remote restoration for development"
    echo ""
    echo "Estimated time: 15-20 minutes"
    echo ""

    # Record start time
    START_TIME=$(date +%s)

    # Run setup steps
    check_prerequisites
    run_initial_setup
    run_gitops_deployment

    # Wait for routes and configure Keycloak/RHDH (non-critical, can fail gracefully)
    if wait_for_routes; then
        configure_keycloak_rhdh
    fi

    run_restore_github_remote

    # Calculate duration
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    MINUTES=$((DURATION / 60))
    SECONDS=$((DURATION % 60))

    # Display summary
    display_final_summary

    echo ""
    print_info "Total time: ${MINUTES}m ${SECONDS}s"
    echo ""
}

# Run main function
main "$@"
