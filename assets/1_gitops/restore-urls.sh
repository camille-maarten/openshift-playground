#!/bin/bash

# ============================================================================
# Restore URL Placeholders Script
# ============================================================================
# This script restores GITEA_URL placeholders in ArgoCD Application manifests
# by replacing actual Gitea URLs with the placeholder.
#
# The setup-gitops-repo.sh script replaces GITEA_URL placeholders with actual
# cluster-specific URLs. This script reverses that change, making the
# manifests portable again.
#
# Usage:
#   ./restore-urls.sh
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
    print_header "Restore URL Placeholders"

    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "${SCRIPT_DIR}"

    print_info "Working directory: ${SCRIPT_DIR}"

    # Find all ArgoCD Application YAML files
    ARGOCD_APP_FILES=$(find . -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \) 2>/dev/null)

    if [ -z "$ARGOCD_APP_FILES" ]; then
        print_warning "No ArgoCD Application YAML files found"
        return 0
    fi

    # Count files to be processed
    FILE_COUNT=0

    # Process each file
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            # Check if file contains a Gitea URL pattern
            if grep -q "repoURL:.*https://.*gitea.*playground-gitops.git" "$file" 2>/dev/null; then
                print_info "Restoring placeholders in: $file"

                # Extract the Gitea base URL from the file
                GITEA_URL=$(grep "repoURL:" "$file" | head -n1 | sed -E 's|.*repoURL: https://([^/]+)/.*|\1|')

                if [ -n "$GITEA_URL" ]; then
                    print_info "  Found Gitea URL: https://${GITEA_URL}"

                    # Replace the full Gitea URL with just "GITEA_URL" placeholder
                    # The URL format is: https://gitea-route/admin/playground-gitops.git
                    # We want to replace it with: GITEA_URL/admin/playground-gitops.git
                    sed -i.bak "s|https://${GITEA_URL}|GITEA_URL|g" "$file"

                    # Remove backup file
                    rm -f "${file}.bak"

                    print_success "  Restored to GITEA_URL placeholder"
                    FILE_COUNT=$((FILE_COUNT + 1))
                else
                    print_warning "  Could not extract Gitea URL from file"
                fi
            else
                print_info "Skipping $file (already has placeholder or no Gitea URL)"
            fi
        fi
    done <<< "$ARGOCD_APP_FILES"

    print_header "Summary"

    if [ $FILE_COUNT -eq 0 ]; then
        print_warning "No files were modified"
        echo "All files already contain GITEA_URL placeholders or no Gitea URLs were found."
    else
        print_success "Restored GITEA_URL placeholders in ${FILE_COUNT} file(s)"
        echo ""
        echo "Files are now portable and ready to be committed to GitHub."
        echo ""
        echo "The following pattern was restored:"
        echo "  Before: repoURL: https://gitea-route.../admin/playground-gitops.git"
        echo "  After:  repoURL: GITEA_URL/admin/playground-gitops.git"
    fi

    echo ""
    print_success "URL placeholder restoration complete!"
}

# Run main function
main
