#!/bin/bash

# ============================================================================
# Test URL Replacement Script
# ============================================================================
# This script tests the URL replacement logic without modifying actual files
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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_OUTPUT_DIR="${SCRIPT_DIR}/output"

# Clean and create output directory
rm -rf "${TEST_OUTPUT_DIR}"
mkdir -p "${TEST_OUTPUT_DIR}/apps"

print_header "URL Replacement Test"

# ============================================================================
# GET ACTUAL GITEA ROUTE FROM CLUSTER
# ============================================================================

print_info "Getting Gitea route from cluster..."

GITEA_NAMESPACE="gitea"
GITEA_ADMIN_USER="admin"
REPO_NAME="playground-gitops"

# Get actual Gitea route
GITEA_ROUTE=$(oc get route gitea -n ${GITEA_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -z "$GITEA_ROUTE" ]; then
    print_error "Could not find Gitea route. Make sure you're logged into OpenShift"
    print_info "Using simulated route for testing..."
    GITEA_ROUTE="gitea-gitea.apps.cluster-f4r9v.f4r9v.sandbox3548.opentlc.com"
fi

print_success "Gitea route: ${GITEA_ROUTE}"

# Build target repo URL
TARGET_REPO_URL="https://${GITEA_ROUTE}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"
GITEA_BASE_URL="https://${GITEA_ROUTE}"

print_info "Target repo URL: ${TARGET_REPO_URL}"
print_info "Gitea base URL: ${GITEA_BASE_URL}"

# ============================================================================
# CREATE TEST TEMPLATE FILES
# ============================================================================

print_header "Creating Test Template Files"

# Create playground-apps.yaml template
cat > "${TEST_OUTPUT_DIR}/playground-apps.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: playground-apps
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: GITEA_URL/admin/playground-gitops.git
    targetRevision: main
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-gitops
EOF

print_success "Created playground-apps.yaml template"

# Create developer-hub app template
cat > "${TEST_OUTPUT_DIR}/apps/03-developer-hub.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: developer-hub
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: GITEA_URL/admin/playground-gitops.git
    targetRevision: main
    path: developerhub/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: rhdh
EOF

print_success "Created apps/03-developer-hub.yaml template"

# Create keycloak app template
cat > "${TEST_OUTPUT_DIR}/apps/11-keycloak.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: GITEA_URL/admin/playground-gitops.git
    targetRevision: main
    path: keycloak/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: keycloak
EOF

print_success "Created apps/11-keycloak.yaml template"

# Create a file with OLD cluster URL (simulate re-running script)
cat > "${TEST_OUTPUT_DIR}/apps/02-kafka-operator.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kafka-operator
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://gitea-gitea.apps.cluster-52rbx.52rbx.sandbox5350.opentlc.com/admin/playground-gitops.git
    targetRevision: main
    path: kafka/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka
EOF

print_success "Created apps/02-kafka-operator.yaml with old cluster URL"

# ============================================================================
# APPLY URL REPLACEMENT LOGIC
# ============================================================================

print_header "Applying URL Replacement Logic"

# Find all ArgoCD Application YAML files
ARGOCD_APP_FILES=$(find "${TEST_OUTPUT_DIR}" -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \))

FILE_COUNT=0
while IFS= read -r file; do
    if [ -f "$file" ]; then
        print_info "Processing: $(basename $file)"

        # Show before
        echo "  BEFORE:"
        grep "repoURL:" "$file" | sed 's/^/    /'

        # Apply replacement logic (SIMPLIFIED - matches fixed setup-gitops-repo.sh)

        # Step 1: Replace GITEA_URL placeholder with full URL (including https://)
        sed -i.bak "s|GITEA_URL|https://${GITEA_ROUTE}|g" "$file"

        # Step 2: Replace any existing repoURL line that references playground-gitops
        # This handles old cluster URLs, GitHub URLs, placeholder URLs, etc.
        sed -i.bak "s|repoURL: https://[^/]*/[^/]*/playground-gitops\.git|repoURL: ${TARGET_REPO_URL}|g" "$file"

        # Step 3: Also handle URLs without https:// (in case of template with just hostname)
        sed -i.bak "s|repoURL: [^/]*\.apps\.[^/]*/admin/playground-gitops\.git|repoURL: ${TARGET_REPO_URL}|g" "$file"

        # Step 4: Handle GitHub or other external URLs if present
        sed -i.bak "s|repoURL:.*github.com.*/playground-gitops.*|repoURL: ${TARGET_REPO_URL}|g" "$file"
        sed -i.bak "s|repoURL:.*YOUR_ORG/YOUR_REPO.*|repoURL: ${TARGET_REPO_URL}|g" "$file"

        # Remove backup
        rm -f "${file}.bak"

        # Show after
        echo "  AFTER:"
        grep "repoURL:" "$file" | sed 's/^/    /'
        echo ""

        FILE_COUNT=$((FILE_COUNT + 1))
    fi
done <<< "$ARGOCD_APP_FILES"

print_success "Processed ${FILE_COUNT} files"

# ============================================================================
# VALIDATION
# ============================================================================

print_header "Validation Results"

ERRORS=0

# Check each file
while IFS= read -r file; do
    if [ -f "$file" ]; then
        REPO_URL=$(grep "repoURL:" "$file" | awk '{print $2}')

        if [ "$REPO_URL" = "${TARGET_REPO_URL}" ]; then
            print_success "$(basename $file): ✓ Correct URL"
        else
            print_error "$(basename $file): ✗ Wrong URL"
            echo "  Expected: ${TARGET_REPO_URL}"
            echo "  Got:      ${REPO_URL}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done <<< "$ARGOCD_APP_FILES"

echo ""

if [ $ERRORS -eq 0 ]; then
    print_success "All URLs are correct! ✓"
    echo ""
    print_info "Test files are stored in: ${TEST_OUTPUT_DIR}"
    print_info "You can inspect them to verify the results"
else
    print_error "Found ${ERRORS} file(s) with incorrect URLs"
    echo ""
    print_info "Check the output above to see which files have issues"
    print_info "Test files are stored in: ${TEST_OUTPUT_DIR}"
    exit 1
fi

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

print_header "Summary"

echo "Current Gitea route: ${GITEA_ROUTE}"
echo "Expected repo URL:   ${TARGET_REPO_URL}"
echo ""
echo "Files processed: ${FILE_COUNT}"
echo "Validation errors: ${ERRORS}"
echo ""
print_info "To inspect the test output files:"
echo "  cd ${TEST_OUTPUT_DIR}"
echo "  cat playground-apps.yaml"
echo "  cat apps/03-developer-hub.yaml"
echo ""
