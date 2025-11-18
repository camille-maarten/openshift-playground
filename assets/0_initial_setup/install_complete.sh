#!/bin/bash

# ============================================================================
# Complete Installation Script - Installs ArgoCD + Gitea
# ============================================================================
# This is a convenience wrapper that installs both ArgoCD and Gitea
# automatically without prompting for options.
#
# Usage:
#   ./install_complete.sh
#
# What it does:
#   - Installs Red Hat OpenShift GitOps (ArgoCD)
#   - Installs Gitea Git server
#   - Configures authentication and RBAC
#   - Sets up default credentials
#
# For more control over installation options, use install.sh instead
# ============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo "${BLUE}ℹ ${NC} $1"
}

print_success() {
    echo "${GREEN}✓${NC} $1"
}

print_error() {
    echo "${RED}✗${NC} $1"
}

print_warning() {
    echo "${YELLOW}⚠${NC} $1"
}

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════════════╗"
echo "║                    COMPLETE OPENSHIFT GITOPS INSTALLATION                         ║"
echo "╚═══════════════════════════════════════════════════════════════════════════════════╝"
echo ""

print_info "This script will automatically install:"
echo "  1. Red Hat OpenShift GitOps (ArgoCD)"
echo "  2. Gitea Git Server"
echo ""
print_info "Default credentials:"
echo "  ArgoCD:  admin / argocd1234!! or admin-user / argocd1234!"
echo "  Gitea:   admin / gitea1234!"
echo ""

# Check if install.sh exists
if [ ! -f "${SCRIPT_DIR}/install.sh" ]; then
    print_error "install.sh not found in ${SCRIPT_DIR}"
    exit 1
fi

echo ""
print_info "Starting complete installation..."
echo ""

# Run install.sh with automatic responses
# Input "1" to select Gitea option
echo "1" | bash "${SCRIPT_DIR}/install.sh"

# Check if installation was successful
if [ $? -eq 0 ]; then
    echo ""
    print_success "╔═══════════════════════════════════════════════════════════════════════════════════╗"
    print_success "║                    INSTALLATION COMPLETED SUCCESSFULLY!                           ║"
    print_success "╚═══════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
else
    echo ""
    print_error "╔═══════════════════════════════════════════════════════════════════════════════════╗"
    print_error "║                        INSTALLATION FAILED!                                       ║"
    print_error "╚═══════════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    print_error "Please check the error messages above and try again."
    echo ""
    print_info "For troubleshooting:"
    echo "  - Check that you have cluster-admin privileges"
    echo "  - Verify oc and helm are installed"
    echo "  - Review the logs above for specific errors"
    echo ""
    exit 1
fi
