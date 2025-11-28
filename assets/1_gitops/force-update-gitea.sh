#!/bin/bash

# ============================================================================
# Force Update Gitea with Correct URLs
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

print_info "Force updating Gitea with correct URLs..."

# Get Gitea route
GITEA_ROUTE=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -z "$GITEA_ROUTE" ]; then
    print_error "Could not get Gitea route"
    exit 1
fi

TARGET_URL="https://${GITEA_ROUTE}/admin/playground-gitops.git"
print_success "Target URL: $TARGET_URL"

# Update all files
print_info "Updating files..."
for f in playground-apps.yaml apps/*.yaml; do
    if [ -f "$f" ]; then
        # Replace GITEA_URL with full URL
        sed -i.bak "s|GITEA_URL|https://${GITEA_ROUTE}|g" "$f"
        # Replace any existing repoURL
        sed -i.bak "s|repoURL: https://[^/]*/[^/]*/playground-gitops\.git|repoURL: ${TARGET_URL}|g" "$f"
        # Clean up
        rm -f "${f}.bak"
    fi
done

# Validate
print_info "Validating..."
./validate-urls-before-push.sh || {
    print_error "Validation failed!"
    exit 1
}

# Commit
print_info "Committing changes..."
git add playground-apps.yaml apps/*.yaml
git commit -m "Fix: Update all ArgoCD app URLs to current cluster

Updated repoURL in all ArgoCD Application manifests to point to current
cluster's Gitea instance: ${GITEA_ROUTE}

This fixes the 'no such host' error in ArgoCD." || {
    print_info "No changes to commit (files may already be correct)"
}

# Push to gitea main branch (force)
print_info "Force pushing to gitea/main..."
git push gitea HEAD:main --force

print_success "Gitea updated successfully!"
print_info "Verifying..."

# Clone and check
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
git clone "https://${GITEA_ROUTE}/admin/playground-gitops.git" check
cd check
echo ""
print_info "URLs in Gitea:"
grep "repoURL:" playground-apps.yaml | sed 's/^/  /'
grep "repoURL:" apps/03-developer-hub.yaml | sed 's/^/  /'
cd /
rm -rf "$TMPDIR"
