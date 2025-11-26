#!/bin/bash

# ============================================================================
# GitOps Repository Setup Script
# ============================================================================
# This script creates a Gitea repository and pushes the GitOps manifests
# to it for use with ArgoCD.
#
# Prerequisites:
# - Gitea instance running and accessible
# - Git CLI installed
# - curl installed
# - jq installed (for JSON parsing)
#
# Usage:
#   ./setup-gitops-repo.sh
# ============================================================================

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

REPO_NAME="playground-gitops"
GITEA_NAMESPACE="gitea"
GITEA_ADMIN_USER="admin"
GITEA_ADMIN_PASSWORD="gitea1234!"

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
# PREREQUISITES CHECK
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"

    local missing_tools=()

    # Check for required tools
    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi

    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi

    if ! command -v oc &> /dev/null; then
        missing_tools+=("oc")
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install missing tools and try again"
        exit 1
    fi

    print_success "All prerequisites met"
}

# ============================================================================
# GET GITEA URL
# ============================================================================

get_gitea_url() {
    print_header "Getting Gitea URL"

    # Get Gitea route
    GITEA_ROUTE=$(oc get route gitea -n ${GITEA_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -z "$GITEA_ROUTE" ]; then
        print_error "Could not find Gitea route in namespace ${GITEA_NAMESPACE}"
        print_info "Make sure Gitea is installed and running"
        exit 1
    fi

    GITEA_URL="https://${GITEA_ROUTE}"
    GITEA_API_URL="${GITEA_URL}/api/v1"

    print_success "Gitea URL: ${GITEA_URL}"
}

# ============================================================================
# TEST GITEA CONNECTION
# ============================================================================

test_gitea_connection() {
    print_header "Testing Gitea Connection"

    # Test basic connectivity
    if curl -k -s -f "${GITEA_URL}" > /dev/null; then
        print_success "Gitea is reachable"
    else
        print_error "Cannot connect to Gitea at ${GITEA_URL}"
        print_info "Please check that Gitea is running and accessible"
        exit 1
    fi

    # Test API with credentials
    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
        -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
        "${GITEA_API_URL}/user")

    if [ "$HTTP_CODE" == "200" ]; then
        print_success "Authentication successful"
    else
        print_error "Authentication failed (HTTP ${HTTP_CODE})"
        print_info "Please check Gitea credentials"
        exit 1
    fi
}

# ============================================================================
# CHECK IF REPOSITORY EXISTS
# ============================================================================

check_repository_exists() {
    print_header "Checking Repository Status"

    HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
        -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
        "${GITEA_API_URL}/repos/${GITEA_ADMIN_USER}/${REPO_NAME}")

    if [ "$HTTP_CODE" == "200" ]; then
        print_warning "Repository '${REPO_NAME}' already exists"
        REPO_EXISTS=true
    else
        print_info "Repository '${REPO_NAME}' does not exist"
        REPO_EXISTS=false
    fi
}

# ============================================================================
# CREATE REPOSITORY
# ============================================================================

create_repository() {
    if [ "$REPO_EXISTS" == "true" ]; then
        print_info "Skipping repository creation (already exists)"
        return 0
    fi

    print_header "Creating Repository"

    # Retry logic for repository creation (handle temporary Gitea errors)
    MAX_RETRIES=3
    RETRY_DELAY=10

    for attempt in $(seq 1 $MAX_RETRIES); do
        if [ $attempt -gt 1 ]; then
            print_info "Retry attempt $attempt/$MAX_RETRIES..."
            sleep $RETRY_DELAY
        fi

        # Create repository via Gitea API
        RESPONSE=$(curl -k -s -w "\n%{http_code}" \
            -u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}" \
            -H "Content-Type: application/json" \
            -X POST \
            -d "{
                \"name\": \"${REPO_NAME}\",
                \"description\": \"GitOps manifests for OpenShift playground\",
                \"private\": false,
                \"auto_init\": false,
                \"default_branch\": \"main\"
            }" \
            "${GITEA_API_URL}/user/repos")

        HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
        BODY=$(echo "$RESPONSE" | sed '$d')

        if [ "$HTTP_CODE" == "201" ]; then
            print_success "Repository '${REPO_NAME}' created successfully"
            REPO_EXISTS=true
            return 0
        elif [ "$HTTP_CODE" == "500" ] && [ $attempt -lt $MAX_RETRIES ]; then
            print_warning "Gitea returned HTTP 500 (temporary error), retrying..."
            continue
        else
            break
        fi
    done

    # If we get here, all retries failed
    print_error "Failed to create repository (HTTP ${HTTP_CODE})"
    echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"

    if [ "$HTTP_CODE" == "500" ]; then
        print_warning "Gitea may not be fully initialized. Try restarting the Gitea pod:"
        print_info "oc delete pod -n gitea -l app.kubernetes.io/name=gitea"
        print_info "Then wait 30 seconds and retry this script"
    fi

    exit 1
}

# ============================================================================
# SETUP LOCAL GIT REPOSITORY
# ============================================================================

setup_local_repo() {
    print_header "Setting Up Local Repository"

    # Get the directory where this script is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    GITOPS_DIR="${SCRIPT_DIR}"

    cd "${GITOPS_DIR}"

    # Initialize git if not already initialized
    if [ ! -d ".git" ]; then
        print_info "Initializing git repository..."
        git init
        git checkout -b main 2>/dev/null || git checkout main
    else
        print_info "Git repository already initialized"
    fi

    # Configure git user (if not set)
    if [ -z "$(git config user.name)" ]; then
        git config user.name "GitOps Admin"
    fi

    if [ -z "$(git config user.email)" ]; then
        git config user.email "gitops@playground.local"
    fi

    # Add .gitignore if it doesn't exist
    if [ ! -f ".gitignore" ]; then
        cat > .gitignore <<EOF
# Temporary files
*.tmp
*.swp
*~

# OS files
.DS_Store
Thumbs.db

# IDE files
.vscode/
.idea/
*.iml

# Backup files
*.bak
EOF
        print_info "Created .gitignore file"
    fi

    print_success "Local repository setup complete"
}

# ============================================================================
# UPDATE ARGOCD APPLICATION REPO URLS
# ============================================================================

update_argocd_repo_urls() {
    print_header "Updating ArgoCD Application Repository URLs"

    # Target repository URL (without credentials)
    TARGET_REPO_URL="https://${GITEA_ROUTE}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"

    print_info "Target repository URL: ${TARGET_REPO_URL}"

    # Find all ArgoCD Application YAML files
    # This includes playground-apps.yaml and all files in the apps/ directory
    ARGOCD_APP_FILES=$(find . -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \) 2>/dev/null)

    if [ -z "$ARGOCD_APP_FILES" ]; then
        print_warning "No ArgoCD Application YAML files found"
        return 0
    fi

    # Update each file
    FILE_COUNT=0
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            print_info "Updating: $file"

            # Replace GITEA_URL placeholder with base Gitea URL (without repo path)
            # Templates include the repo path, so we only replace with base URL
            GITEA_BASE_URL="https://${GITEA_ROUTE}"
            sed -i.bak "s|GITEA_URL|${GITEA_BASE_URL}|g" "$file"

            # Also handle any legacy patterns
            sed -i.bak "s|repoURL:.*github.com.*|repoURL: ${TARGET_REPO_URL}|g" "$file"
            sed -i.bak "s|repoURL:.*YOUR_ORG/YOUR_REPO.*|repoURL: ${TARGET_REPO_URL}|g" "$file"

            # Replace any existing repoURL (including old Gitea URLs from other clusters)
            sed -i.bak "s|repoURL: https://.*|repoURL: ${TARGET_REPO_URL}|g" "$file"

            # Fix the path field - remove assets/1_gitops/ prefix since we're pushing from that directory
            # The repository root in Gitea IS assets/1_gitops/, so paths should be relative to that
            sed -i.bak "s|path: assets/1_gitops/|path: |g" "$file"

            # Remove backup files
            rm -f "${file}.bak"

            FILE_COUNT=$((FILE_COUNT + 1))
        fi
    done <<< "$ARGOCD_APP_FILES"

    print_success "Updated ${FILE_COUNT} ArgoCD Application manifest(s)"
}

# ============================================================================
# ADD GIT REMOTE
# ============================================================================

add_git_remote() {
    print_header "Configuring Git Remote"

    REPO_URL="https://${GITEA_ADMIN_USER}:${GITEA_ADMIN_PASSWORD}@${GITEA_ROUTE}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"

    # Remove existing gitea remote if it exists
    if git remote | grep -q "^gitea$"; then
        print_info "Removing existing 'gitea' remote..."
        git remote remove gitea
    fi

    # Add gitea remote
    print_info "Adding 'gitea' remote..."
    git remote add gitea "${REPO_URL}"

    print_success "Git remote configured"
}

# ============================================================================
# COMMIT AND PUSH CHANGES
# ============================================================================

commit_and_push() {
    print_header "Committing and Pushing Changes"

    # Add all files
    print_info "Staging files..."
    git add .

    # Check if there are changes to commit
    if git diff --staged --quiet; then
        print_info "No changes to commit"
    else
        # Commit changes
        print_info "Committing changes..."
        git commit -m "Initial commit: GitOps manifests for OpenShift playground

This commit includes:
- App-of-Apps pattern (apps/ directory with child applications)
- Developer Hub manifests and configuration
- Kafka operator installation manifests
- Playground namespace with resource quotas and network policies
- Documentation for all components

App-of-Apps Structure:
- playground-apps.yaml: Parent application that manages all child apps
- apps/: Directory containing child application definitions

Generated on: $(date '+%Y-%m-%d %H:%M:%S')"
    fi

    # Push to Gitea
    print_info "Pushing to Gitea..."

    # Disable SSL verification for self-signed certificates
    git config http.sslVerify false

    if git push -u gitea main --force 2>&1; then
        print_success "Successfully pushed to Gitea"
    else
        print_error "Failed to push to Gitea"
        exit 1
    fi
}

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

display_summary() {
    print_header "Setup Complete"

    echo "Repository Information:"
    echo "  Name:        ${REPO_NAME}"
    echo "  URL:         ${GITEA_URL}/${GITEA_ADMIN_USER}/${REPO_NAME}"
    echo "  Clone URL:   ${GITEA_URL}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"
    echo ""
    echo "Credentials:"
    echo "  Username:    ${GITEA_ADMIN_USER}"
    echo "  Password:    ${GITEA_ADMIN_PASSWORD}"
    echo ""
    echo "Next Steps:"
    echo "  1. Access the repository in Gitea: ${GITEA_URL}/${GITEA_ADMIN_USER}/${REPO_NAME}"
    echo "  2. Use deploy-to-argocd.sh to create ArgoCD Applications"
    echo "  3. ArgoCD will automatically sync from: ${GITEA_URL}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"
    echo ""
    echo "Note: All argocd-application.yaml files have been automatically updated"
    echo "      with the correct Gitea repository URL."
    echo ""

    print_success "GitOps repository setup complete!"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

# ============================================================================
# RESTORE TEMPLATE FILES
# ============================================================================

restore_template_files() {
    print_header "Restoring Template Files"

    # Get parent repository (openshift-playground)
    PARENT_REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

    # Check if we're in a git repository
    if [ -d "${PARENT_REPO}/.git" ]; then
        print_info "Restoring template files to GITEA_URL placeholders..."

        cd "${PARENT_REPO}"

        # Restore the template files from the main repository
        git restore assets/1_gitops/playground-apps.yaml \
                   assets/1_gitops/apps/01-playground-namespaces.yaml \
                   assets/1_gitops/apps/02-kafka-operator.yaml \
                   assets/1_gitops/apps/03-developer-hub.yaml 2>/dev/null || true

        print_success "Template files restored"
    else
        print_info "Not in parent git repository, skipping template restoration"
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    print_header "GitOps Repository Setup"

    # Run setup steps
    check_prerequisites
    get_gitea_url
    test_gitea_connection
    check_repository_exists
    create_repository
    setup_local_repo
    update_argocd_repo_urls
    add_git_remote
    commit_and_push
    restore_template_files
    display_summary
}

# Run main function
main
