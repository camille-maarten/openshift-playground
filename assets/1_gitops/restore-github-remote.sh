#!/bin/bash

# ============================================================================
# Restore GitHub Remote Script
# ============================================================================
# This script restores the GitHub repository as the git remote in the main
# openshift-playground repository.
#
# Note: The setup-gitops-repo.sh script creates a separate git repository
# in assets/1_gitops/.git for pushing to Gitea. This script works with the
# MAIN repository (openshift-playground), not that subdirectory repository.
#
# The script removes any Gitea remote and ensures the origin remote points
# to GitHub for development and pushing changes.
#
# Usage:
#   ./restore-github-remote.sh
# ============================================================================

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

GITHUB_REPO="git@github.com:camille-maarten/openshift-playground.git"

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
    print_header "Restore GitHub Remote"

    # Navigate to parent repository (openshift-playground), not the gitops subdirectory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PARENT_REPO="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    cd "${PARENT_REPO}"

    print_info "Working with main repository at: ${PARENT_REPO}"

    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        print_info "This script must be run from within the openshift-playground repository"
        exit 1
    fi

    # Show current remotes
    print_header "Current Git Remotes"
    git remote -v

    # Check if gitea remote exists
    if git remote | grep -q "^gitea$"; then
        print_info "Found 'gitea' remote, removing it..."
        git remote remove gitea
        print_success "Gitea remote removed"
    else
        print_info "No 'gitea' remote found (already clean)"
    fi

    # Check if origin remote exists
    if git remote | grep -q "^origin$"; then
        print_warning "Remote 'origin' already exists"

        CURRENT_ORIGIN=$(git remote get-url origin)
        print_info "Current origin URL: ${CURRENT_ORIGIN}"

        if [ "$CURRENT_ORIGIN" != "$GITHUB_REPO" ]; then
            print_warning "Origin URL doesn't match expected GitHub repository"
            print_info "Expected: ${GITHUB_REPO}"
            print_info "Current:  ${CURRENT_ORIGIN}"

            read -p "Update origin to GitHub repository? (y/n) [y]: " UPDATE_ORIGIN
            UPDATE_ORIGIN=${UPDATE_ORIGIN:-y}

            if [ "$UPDATE_ORIGIN" == "y" ]; then
                print_info "Updating origin remote URL..."
                git remote set-url origin "${GITHUB_REPO}"
                print_success "Origin remote URL updated"
            else
                print_info "Keeping existing origin remote"
            fi
        else
            print_success "Origin already points to GitHub repository"
        fi
    else
        print_info "Adding 'origin' remote pointing to GitHub..."
        git remote add origin "${GITHUB_REPO}"
        print_success "Origin remote added"
    fi

    # Show updated remotes
    print_header "Updated Git Remotes"
    git remote -v

    print_header "Summary"
    echo "Git remote configuration updated in main repository:"
    echo "  - Working directory: ${PARENT_REPO}"
    echo "  - Gitea remote removed (if it existed)"
    echo "  - GitHub remote configured as 'origin'"
    echo "  - Repository: ${GITHUB_REPO}"
    echo ""
    echo "You can now push to GitHub using:"
    echo "  cd ${PARENT_REPO}"
    echo "  git push origin <branch-name>"
    echo ""
    echo "Note: The local git repository in assets/1_gitops/.git is separate"
    echo "      and used only for pushing to Gitea. This script updates the"
    echo "      main repository remote. ArgoCD applications will continue to"
    echo "      pull from Gitea (configured in the cluster)."
    echo ""

    print_success "GitHub remote restoration complete!"
}

# Run main function
main
