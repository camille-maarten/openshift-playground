#!/bin/bash

# ============================================================================
# Cleanup for GitHub Script
# ============================================================================
# This script prepares the repository for committing to GitHub by:
# 1. Restoring URL placeholders in ArgoCD Application manifests
# 2. Restoring GitHub remote configuration in the main repository
#
# Run this script before committing and pushing changes to GitHub.
#
# Usage:
#   ./cleanup-for-github.sh
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
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "Cleanup for GitHub Commit"

    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    print_info "Script directory: ${SCRIPT_DIR}"

    # Step 1: Restore URL placeholders
    print_header "Step 1: Restore URL Placeholders"

    if [ -f "${SCRIPT_DIR}/restore-urls.sh" ]; then
        print_info "Running restore-urls.sh..."
        bash "${SCRIPT_DIR}/restore-urls.sh"
    else
        print_error "restore-urls.sh not found in ${SCRIPT_DIR}"
        exit 1
    fi

    # Step 2: Restore GitHub remote
    print_header "Step 2: Restore GitHub Remote"

    if [ -f "${SCRIPT_DIR}/restore-github-remote.sh" ]; then
        print_info "Running restore-github-remote.sh..."
        bash "${SCRIPT_DIR}/restore-github-remote.sh"
    else
        print_error "restore-github-remote.sh not found in ${SCRIPT_DIR}"
        exit 1
    fi

    # Final summary
    print_header "Cleanup Complete"

    echo "Your repository is now ready for GitHub!"
    echo ""
    echo "What was done:"
    echo "  ✓ Restored GITEA_URL placeholders in ArgoCD manifests"
    echo "  ✓ Configured GitHub as the 'origin' remote"
    echo "  ✓ Removed any Gitea remote from main repository"
    echo ""
    echo "Next steps:"
    echo "  1. Navigate to repository root:"
    echo "     cd $(cd "${SCRIPT_DIR}/../.." && pwd)"
    echo ""
    echo "  2. Verify your branch and status:"
    echo "     git branch"
    echo "     git status"
    echo "     git remote -v"
    echo ""
    echo "  3. Stage and commit your changes:"
    echo "     git add ."
    echo "     git commit -m \"Your commit message\""
    echo ""
    echo "  4. Push to GitHub:"
    echo "     git push origin <your-branch>"
    echo ""

    print_success "All cleanup tasks completed successfully!"
}

# Run main function
main
