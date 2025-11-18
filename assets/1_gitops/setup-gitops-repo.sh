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
    else
        print_error "Failed to create repository (HTTP ${HTTP_CODE})"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY"
        exit 1
    fi
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
- Developer Hub manifests and configuration
- Kafka operator installation manifests
- Playground namespace with resource quotas and network policies
- Documentation for all components

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
    echo "  2. Configure ArgoCD Applications to use this repository"
    echo "  3. Update ArgoCD Application manifests with the correct repoURL:"
    echo "     repoURL: ${GITEA_URL}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"
    echo ""

    print_success "GitOps repository setup complete!"
}

# ============================================================================
# MAIN EXECUTION
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
    add_git_remote
    commit_and_push
    display_summary
}

# Run main function
main
