#!/bin/bash

# ============================================================================
# Upload and Deploy Script
# ============================================================================
# This script automates the complete GitOps workflow:
# 1. Uploads all GitOps manifests to Gitea repository
# 2. Deploys ArgoCD Applications using App-of-Apps pattern
#
# Prerequisites:
# - OpenShift GitOps (ArgoCD) installed and running
# - Gitea installed and running
# - oc CLI installed and logged in
# - git, curl, and jq installed
#
# Usage:
#   ./upload-and-deploy.sh
# ============================================================================

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

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
    echo "${CYAN}========================================${NC}"
    echo "${CYAN}$1${NC}"
    echo "${CYAN}========================================${NC}"
    echo ""
}

print_step() {
    echo ""
    echo "${MAGENTA}>>> Step $1: $2${NC}"
    echo ""
}

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    local MISSING_TOOLS=()

    # Check for required tools
    if ! command -v oc &> /dev/null; then
        MISSING_TOOLS+=("oc")
    fi

    if ! command -v git &> /dev/null; then
        MISSING_TOOLS+=("git")
    fi

    if ! command -v curl &> /dev/null; then
        MISSING_TOOLS+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        MISSING_TOOLS+=("jq")
    fi

    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        print_error "Missing required tools: ${MISSING_TOOLS[*]}"
        echo ""
        echo "Please install the missing tools and try again."
        exit 1
    fi

    # Check if logged into OpenShift
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift"
        echo ""
        echo "Please run 'oc login' first and try again."
        exit 1
    fi

    print_info "Logged in as: $(oc whoami)"

    # Check if required scripts exist
    if [ ! -f "${SCRIPT_DIR}/setup-gitops-repo.sh" ]; then
        print_error "setup-gitops-repo.sh not found in ${SCRIPT_DIR}"
        exit 1
    fi

    if [ ! -f "${SCRIPT_DIR}/deploy-to-argocd.sh" ]; then
        print_error "deploy-to-argocd.sh not found in ${SCRIPT_DIR}"
        exit 1
    fi

    # Make sure scripts are executable
    chmod +x "${SCRIPT_DIR}/setup-gitops-repo.sh"
    chmod +x "${SCRIPT_DIR}/deploy-to-argocd.sh"

    print_success "All prerequisites met"
}

# ============================================================================
# RUN SETUP GITOPS REPO
# ============================================================================

run_setup_gitops_repo() {
    print_step "1" "Upload GitOps Manifests to Gitea"

    print_info "Running setup-gitops-repo.sh..."
    echo ""

    if bash "${SCRIPT_DIR}/setup-gitops-repo.sh"; then
        print_success "GitOps manifests uploaded to Gitea successfully"
    else
        print_error "Failed to upload GitOps manifests to Gitea"
        exit 1
    fi
}

# ============================================================================
# RUN DEPLOY TO ARGOCD (APP-OF-APPS)
# ============================================================================

run_deploy_to_argocd() {
    print_step "2" "Deploy ArgoCD Applications (App-of-Apps Pattern)"

    print_info "Running deploy-to-argocd.sh with App-of-Apps pattern..."
    echo ""

    # Automatically select option 2 (App-of-Apps) by piping "2" to the script
    if echo "2" | bash "${SCRIPT_DIR}/deploy-to-argocd.sh"; then
        print_success "ArgoCD Applications deployed successfully"
    else
        print_error "Failed to deploy ArgoCD Applications"
        exit 1
    fi
}

# ============================================================================
# VERIFY DEPLOYMENT
# ============================================================================

verify_deployment() {
    print_header "Verifying Deployment"

    ARGOCD_NAMESPACE="openshift-gitops"

    print_info "Checking ArgoCD Applications..."
    echo ""

    # Check if playground-apps exists (the App-of-Apps)
    if oc get application playground-apps -n ${ARGOCD_NAMESPACE} &> /dev/null; then
        print_success "App-of-Apps 'playground-apps' found"
    else
        print_warning "App-of-Apps 'playground-apps' not found"
    fi

    # Wait a few seconds for child apps to be created
    print_info "Waiting for child applications to be created..."
    sleep 5

    # List all applications
    echo ""
    print_info "ArgoCD Applications:"
    oc get applications -n ${ARGOCD_NAMESPACE} -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || echo "  (None found yet)"
    echo ""
}

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

display_summary() {
    print_header "Deployment Complete"

    ARGOCD_NAMESPACE="openshift-gitops"
    GITEA_NAMESPACE="gitea"

    # Get URLs
    ARGOCD_URL=$(oc get route openshift-gitops-server -n ${ARGOCD_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
    GITEA_URL=$(oc get route gitea -n ${GITEA_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")

    echo "Summary:"
    echo "  ✓ GitOps manifests uploaded to Gitea"
    echo "  ✓ ArgoCD App-of-Apps created: playground-apps"
    echo "  ✓ Child applications will be automatically discovered and synced"
    echo ""
    echo "Access Points:"
    echo "  ArgoCD UI:  https://${ARGOCD_URL}"
    echo "  Gitea UI:   https://${GITEA_URL}/admin/playground-gitops"
    echo ""
    echo "Expected Child Applications:"
    echo "  1. playground-namespaces  - Playground namespace with quotas and policies"
    echo "  2. kafka-operator         - AMQ Streams (Kafka) operator"
    echo "  3. developer-hub          - Red Hat Developer Hub"
    echo ""
    echo "Monitor Applications:"
    echo "  # List all applications"
    echo "  oc get applications -n ${ARGOCD_NAMESPACE}"
    echo ""
    echo "  # Watch application status"
    echo "  watch oc get applications -n ${ARGOCD_NAMESPACE}"
    echo ""
    echo "  # Check specific application"
    echo "  oc describe application playground-apps -n ${ARGOCD_NAMESPACE}"
    echo ""
    echo "Troubleshooting:"
    echo "  # If child apps are not appearing, check App-of-Apps logs"
    echo "  oc logs -n ${ARGOCD_NAMESPACE} deployment/openshift-gitops-server"
    echo ""
    echo "  # Force refresh App-of-Apps"
    echo "  oc patch application playground-apps -n ${ARGOCD_NAMESPACE} \\"
    echo "    --type merge -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}'"
    echo ""

    print_success "GitOps workflow complete! Check ArgoCD UI for sync status."
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "Upload and Deploy GitOps Workflow"

    echo "This script will:"
    echo "  1. Upload all GitOps manifests to Gitea repository"
    echo "  2. Deploy ArgoCD Applications using App-of-Apps pattern"
    echo ""
    print_info "Starting automated workflow..."

    # Run workflow steps
    check_prerequisites
    run_setup_gitops_repo
    run_deploy_to_argocd
    verify_deployment
    display_summary
}

# Run main function
main
