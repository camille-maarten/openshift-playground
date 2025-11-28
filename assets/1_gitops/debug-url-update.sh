#!/bin/bash

# ============================================================================
# Debug URL Update Script
# ============================================================================
# This script shows exactly what's happening during URL replacement
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
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

print_header "Debug URL Update"

# Get Gitea info
GITEA_NAMESPACE="gitea"
GITEA_ADMIN_USER="admin"
REPO_NAME="playground-gitops"

GITEA_ROUTE=$(oc get route gitea -n ${GITEA_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -z "$GITEA_ROUTE" ]; then
    print_error "Could not find Gitea route"
    exit 1
fi

TARGET_REPO_URL="https://${GITEA_ROUTE}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"

print_success "Gitea route: ${GITEA_ROUTE}"
print_success "Target URL: ${TARGET_REPO_URL}"
echo ""

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

print_header "Step 1: Find ArgoCD Application Files"

ARGOCD_APP_FILES=$(find . -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \) ! -path "*/test/*" 2>/dev/null)

print_info "Files found:"
echo "$ARGOCD_APP_FILES" | while read file; do
    echo "  - $file"
done
echo ""

print_header "Step 2: Show Current URLs"

echo "$ARGOCD_APP_FILES" | while read file; do
    if [ -f "$file" ]; then
        CURRENT_URL=$(grep "repoURL:" "$file" | awk '{print $2}' || echo "NOT FOUND")
        echo "$(basename $file): $CURRENT_URL"
    fi
done
echo ""

print_header "Step 3: Simulate URL Replacement"

print_info "This shows what WOULD happen (not actually modifying files)"
echo ""

echo "$ARGOCD_APP_FILES" | while read file; do
    if [ -f "$file" ]; then
        echo "File: $file"
        echo "  Current URL:"
        grep "repoURL:" "$file" | sed 's/^/    /'

        # Show what the replacement would produce
        echo "  After replacement would be:"
        grep "repoURL:" "$file" | \
            sed "s|GITEA_URL|https://${GITEA_ROUTE}|g" | \
            sed "s|repoURL: https://[^/]*/[^/]*/playground-gitops\.git|repoURL: ${TARGET_REPO_URL}|g" | \
            sed 's/^/    /'
        echo ""
    fi
done

print_header "Step 4: Check Git Status"

print_info "Current branch:"
git branch --show-current || echo "  Not in a git branch"
echo ""

print_info "Git status:"
git status --short || echo "  Error getting git status"
echo ""

print_info "Git remotes:"
git remote -v || echo "  No remotes configured"
echo ""

print_header "Recommendations"

echo "If URLs are still wrong after running setup-gitops-repo.sh, check:"
echo "  1. Are files being found correctly? (see Step 1 above)"
echo "  2. Are current URLs as expected? (see Step 2 above)"
echo "  3. Would replacement work correctly? (see Step 3 above)"
echo "  4. Is git working properly? (see Step 4 above)"
echo ""
echo "To actually run the update:"
echo "  cd assets/1_gitops"
echo "  ./setup-gitops-repo.sh"
echo ""
