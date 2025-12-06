#!/bin/bash

# ============================================================================
# Sync Missing Applications to Gitea
# ============================================================================
# This script checks for applications that exist locally but not in Gitea
# and adds them to the Gitea repository.
#
# Prerequisites:
# - oc CLI installed and logged in
# - Gitea repository already created
# - playground-config ConfigMap exists
#
# Usage:
#   ./sync-missing-apps.sh
# ============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get BASE_URL from ConfigMap
print_info "Reading BASE_URL from playground-config ConfigMap..."
BASE_URL=$(oc get configmap playground-config -n openshift-gitops -o jsonpath='{.data.BASE_URL}' 2>/dev/null || echo "")

if [ -z "$BASE_URL" ]; then
    print_error "Could not find playground-config ConfigMap"
    print_info "Run: assets/0_initial_setup/install.sh"
    exit 1
fi

GITEA_URL="https://gitea-gitea.${BASE_URL}"
print_success "Gitea URL: ${GITEA_URL}"

# Clone Gitea repository
TMP_DIR=$(mktemp -d)
trap "rm -rf ${TMP_DIR}" EXIT

print_info "Cloning Gitea repository..."
cd "${TMP_DIR}"
git clone "https://admin:gitea1234!@gitea-gitea.${BASE_URL}/admin/playground-gitops.git" 2>&1 | grep -v "password" || true

if [ ! -d "playground-gitops" ]; then
    print_error "Failed to clone Gitea repository"
    exit 1
fi

cd playground-gitops

# Configure git
git config user.name "GitOps Admin"
git config user.email "gitops@playground.local"

# Check for missing directories
print_header "Checking for Missing Directories"

MISSING_DIRS=()
for dir in "${SCRIPT_DIR}"/*/manifests; do
    dir_name=$(basename "$(dirname "$dir")")
    # Skip special directories
    if [[ "$dir_name" == "info" || "$dir_name" == "test" || "$dir_name" == ".git" ]]; then
        continue
    fi

    if [ ! -d "${dir_name}" ]; then
        print_warning "Missing directory: ${dir_name}"
        MISSING_DIRS+=("$dir_name")
        # Copy directory
        cp -r "${SCRIPT_DIR}/${dir_name}" .
    fi
done

# Check for missing app files
print_header "Checking for Missing App Files"

MISSING_APPS=()
for app_file in "${SCRIPT_DIR}"/apps/*.yaml; do
    app_name=$(basename "$app_file")
    # Skip README
    if [[ "$app_name" == "README.md" ]]; then
        continue
    fi

    if [ ! -f "apps/${app_name}" ]; then
        print_warning "Missing app file: ${app_name}"
        MISSING_APPS+=("$app_name")
        # Copy and update app file
        cat "$app_file" | sed "s|GITEA_URL|${GITEA_URL}|g" > "apps/${app_name}"
    fi
done

# Commit and push if there are changes
if [ ${#MISSING_DIRS[@]} -gt 0 ] || [ ${#MISSING_APPS[@]} -gt 0 ]; then
    print_header "Committing Changes"

    git add .

    COMMIT_MSG="Sync missing applications and directories

Missing directories: ${MISSING_DIRS[*]:-none}
Missing app files: ${MISSING_APPS[*]:-none}

Synced on: $(date '+%Y-%m-%d %H:%M:%S')"

    git commit -m "$COMMIT_MSG"

    print_info "Pushing to Gitea..."
    git config http.sslVerify false
    git push 2>&1 | grep -v "password" || true

    print_success "Changes pushed to Gitea"

    # Refresh playground-apps
    print_info "Refreshing playground-apps ArgoCD application..."
    oc patch application playground-apps -n openshift-gitops --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' || true

    print_success "Sync complete!"
    echo ""
    echo "New applications will appear in ArgoCD shortly."
    echo "Check with: oc get applications -n openshift-gitops"
else
    print_success "No missing applications found - everything is in sync!"
fi
