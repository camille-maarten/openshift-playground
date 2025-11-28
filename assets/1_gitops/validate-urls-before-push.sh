#!/bin/bash

# ============================================================================
# Validate URLs Before Push Script
# ============================================================================
# This script validates that all ArgoCD application manifests have the
# correct repoURL before they are pushed to Gitea
# ============================================================================

set -e

# Color codes
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

print_header "Validating ArgoCD Application URLs"

# Get expected Gitea URL
GITEA_NAMESPACE="gitea"
GITEA_ADMIN_USER="admin"
REPO_NAME="playground-gitops"

GITEA_ROUTE=$(oc get route gitea -n ${GITEA_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -z "$GITEA_ROUTE" ]; then
    print_error "Could not find Gitea route. Make sure you're logged into OpenShift"
    exit 1
fi

EXPECTED_REPO_URL="https://${GITEA_ROUTE}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"

print_success "Expected repo URL: ${EXPECTED_REPO_URL}"
echo ""

# Find all ArgoCD app files (exclude test directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APP_FILES=$(find . -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \) ! -path "*/test/*" 2>/dev/null)

if [ -z "$APP_FILES" ]; then
    print_error "No ArgoCD application files found"
    exit 1
fi

print_info "Checking URLs in application files..."
echo ""

ERRORS=0
WARNINGS=0

while IFS= read -r file; do
    if [ -f "$file" ]; then
        FILENAME=$(basename "$file")

        # Get the repoURL from the file
        REPO_URL=$(grep "repoURL:" "$file" 2>/dev/null | awk '{print $2}' || echo "")

        if [ -z "$REPO_URL" ]; then
            print_warning "${FILENAME}: No repoURL found"
            WARNINGS=$((WARNINGS + 1))
        elif [ "$REPO_URL" = "GITEA_URL/admin/playground-gitops.git" ] || [[ "$REPO_URL" == "GITEA_URL"* ]]; then
            print_error "${FILENAME}: Still has GITEA_URL placeholder!"
            echo "  Current: $REPO_URL"
            echo "  Expected: $EXPECTED_REPO_URL"
            ERRORS=$((ERRORS + 1))
        elif [ "$REPO_URL" = "${EXPECTED_REPO_URL}" ]; then
            print_success "${FILENAME}: ✓ Correct URL"
        else
            print_error "${FILENAME}: Wrong cluster URL"
            echo "  Current: $REPO_URL"
            echo "  Expected: $EXPECTED_REPO_URL"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done <<< "$APP_FILES"

echo ""
print_header "Validation Summary"

echo "Files checked: $(echo "$APP_FILES" | wc -l | tr -d ' ')"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "Validation FAILED! Do not push to Gitea yet."
    echo ""
    echo "To fix the URLs, run:"
    echo "  cd assets/1_gitops"
    echo "  ./setup-gitops-repo.sh"
    echo ""
    exit 1
else
    print_success "Validation PASSED! All URLs are correct."
    echo ""
    echo "Safe to push to Gitea."
    exit 0
fi
