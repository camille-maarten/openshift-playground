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
# Calculate parent directory (openshift-playground root)
PARENT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
INITIAL_SETUP_DIR="${PARENT_DIR}/assets/0_initial_setup"
GITOPS_DIR="${PARENT_DIR}/assets/1_gitops"

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
# STEP 3: UPDATE URLS IN GITEA
# ============================================================================

run_update_urls() {
    print_header "Step 3: Update Cluster URLs in Gitea"

    print_info "This will:"
    print_info "  - Wait for routes to be available"
    print_info "  - Update Keycloak, RHDH, and OpenShift URLs"
    print_info "  - Push changes to Gitea repository"
    print_info "  - Trigger ArgoCD sync"
    echo ""

    if [ ! -f "${GITOPS_DIR}/update-keycloak-rhdh-config.sh" ]; then
        print_error "URL update script not found: ${GITOPS_DIR}/update-keycloak-rhdh-config.sh"
        exit 1
    fi

    print_step "Waiting for routes to be available..."

    # Wait for routes to be created (with timeout)
    local max_wait=300
    local wait_time=0
    local check_interval=10

    while [ $wait_time -lt $max_wait ]; do
        # Check if key routes exist
        if oc get route gitea -n gitea &> /dev/null; then
            print_success "Gitea route is available"
            break
        fi

        print_info "Waiting for routes... (${wait_time}s/${max_wait}s)"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done

    if [ $wait_time -ge $max_wait ]; then
        print_warning "Timeout waiting for routes - continuing anyway"
    fi

    print_step "Running update-keycloak-rhdh-config.sh..."

    cd "${GITOPS_DIR}"

    # Run the URL update script
    if ./update-keycloak-rhdh-config.sh; then
        print_success "URLs updated in Gitea repository"
    else
        print_warning "URL update had issues (continuing anyway)"
    fi

    # Return to script directory
    cd "${SCRIPT_DIR}"
}

# ============================================================================
# STEP 4: RESTORE GITHUB REMOTE
# ============================================================================

run_restore_github_remote() {
    print_header "Step 4: Restore GitHub Remote for Development"

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
    echo "  ✓ AMQ Streams (Kafka) operator"
    echo "  ✓ Playground namespace with resource quotas"
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
    echo "Next steps:"
    echo "  1. Access ArgoCD console to monitor deployments"
    echo "  2. Check info/environment_config_platform.md for all details"
    echo "  3. Access Developer Hub to start using the platform"
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
    echo "  2. GitOps repository upload and ArgoCD deployment (includes URL update)"
    echo "  3. GitHub remote restoration for development"
    echo ""
    echo "Estimated time: 10-15 minutes"
    echo ""

    # Record start time
    START_TIME=$(date +%s)

    # Run setup steps
    check_prerequisites
    run_initial_setup
    run_gitops_deployment
    # Note: URL updates now happen automatically in run_gitops_deployment (upload-and-deploy.sh)
    # Uncomment the line below if you want an additional verification pass after all routes are ready
    # run_update_urls
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
