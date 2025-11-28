#!/bin/bash

# ============================================================================
# ArgoCD Application Deployment Script
# ============================================================================
# This script creates ArgoCD Applications that deploy GitOps manifests
# from the Gitea repository to the OpenShift cluster.
#
# Prerequisites:
# - OpenShift GitOps (ArgoCD) installed and running
# - Gitea repository 'playground-gitops' exists with manifests
# - oc CLI installed and logged in
#
# Usage:
#   ./deploy-to-argocd.sh
# ============================================================================

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

ARGOCD_NAMESPACE="openshift-gitops"
GITEA_NAMESPACE="gitea"
REPO_NAME="playground-gitops"
GITEA_ADMIN_USER="admin"

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

    # Check for oc
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI is not installed"
        exit 1
    fi

    # Check if logged in
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift. Please run 'oc login' first"
        exit 1
    fi

    print_info "Logged in as: $(oc whoami)"
    print_success "Prerequisites check passed"
}

# ============================================================================
# GET GITEA URL
# ============================================================================

get_gitea_url() {
    print_header "Getting Gitea Repository URL"

    # Get Gitea route
    GITEA_ROUTE=$(oc get route gitea -n ${GITEA_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

    if [ -z "$GITEA_ROUTE" ]; then
        print_error "Could not find Gitea route in namespace ${GITEA_NAMESPACE}"
        print_info "Make sure Gitea is installed and running"
        exit 1
    fi

    REPO_URL="https://${GITEA_ROUTE}/${GITEA_ADMIN_USER}/${REPO_NAME}.git"

    print_success "Repository URL: ${REPO_URL}"
}

# ============================================================================
# VERIFY ARGOCD IS RUNNING
# ============================================================================

verify_argocd() {
    print_header "Verifying ArgoCD Installation"

    # Check if ArgoCD namespace exists
    if ! oc get namespace ${ARGOCD_NAMESPACE} &> /dev/null; then
        print_error "ArgoCD namespace '${ARGOCD_NAMESPACE}' not found"
        print_info "Please install OpenShift GitOps first"
        exit 1
    fi

    # Check if ArgoCD server is running
    if ! oc get deployment openshift-gitops-server -n ${ARGOCD_NAMESPACE} &> /dev/null; then
        print_error "ArgoCD server deployment not found"
        print_info "Please install OpenShift GitOps first"
        exit 1
    fi

    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD server to be ready..."
    oc wait --for=condition=Available deployment/openshift-gitops-server \
        -n ${ARGOCD_NAMESPACE} --timeout=300s 2>/dev/null || {
        print_warning "ArgoCD server may not be fully ready yet"
    }

    print_success "ArgoCD is running"
}

# ============================================================================
# CREATE ARGOCD APPLICATIONS
# ============================================================================

create_playground_app_of_apps() {
    print_header "Creating Playground App-of-Apps"

    # Create temporary directory for manifests
    TMP_DIR=$(mktemp -d)
    trap "rm -rf ${TMP_DIR}" EXIT

    # Read the playground-apps template and replace GITEA_URL
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATE_FILE="${SCRIPT_DIR}/playground-apps.yaml"

    if [ ! -f "${TEMPLATE_FILE}" ]; then
        print_error "Template file not found: ${TEMPLATE_FILE}"
        exit 1
    fi

    # Replace GITEA_URL in the template with just the base URL (without the repo path)
    # The template includes /admin/playground-gitops.git so we just need the base
    GITEA_BASE_URL="https://${GITEA_ROUTE}"
    sed "s|GITEA_URL|${GITEA_BASE_URL}|g" "${TEMPLATE_FILE}" > "${TMP_DIR}/playground-app-of-apps.yaml"

    print_info "Applying App-of-Apps manifest..."
    oc apply -f "${TMP_DIR}/playground-app-of-apps.yaml"

    print_success "App-of-Apps created: playground-apps"
    print_info "This app manages all child applications from the apps/ directory in Gitea"
}


# ============================================================================
# SYNC APPLICATIONS
# ============================================================================

sync_applications() {
    print_header "Syncing ArgoCD Applications"

    # Check if argocd CLI is available
    if command -v argocd &> /dev/null; then
        print_info "Using ArgoCD CLI to sync applications..."

        # Get ArgoCD server route
        ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n ${ARGOCD_NAMESPACE} -o jsonpath='{.spec.host}')

        # Login to ArgoCD (using admin user)
        ARGOCD_PASSWORD=$(oc get secret openshift-gitops-cluster -n ${ARGOCD_NAMESPACE} -o jsonpath='{.data.admin\.password}' | base64 -d)

        argocd login ${ARGOCD_ROUTE} --username admin --password ${ARGOCD_PASSWORD} --insecure || {
            print_warning "Could not login to ArgoCD CLI, skipping sync"
            return 0
        }

        # Sync applications
        print_info "Syncing playground-namespaces..."
        argocd app sync playground-namespaces --insecure || print_warning "Sync failed for playground-namespaces"

        print_info "Syncing kafka-operator..."
        argocd app sync kafka-operator --insecure || print_warning "Sync failed for kafka-operator"

        print_info "Syncing developer-hub..."
        argocd app sync developer-hub --insecure || print_warning "Sync failed for developer-hub"

        print_success "Applications synced"
    else
        print_warning "ArgoCD CLI not found, skipping automatic sync"
        print_info "Applications will auto-sync based on their configuration"
    fi
}

# ============================================================================
# CREATE ENVIRONMENT CONFIGURATION FILE
# ============================================================================

create_environment_config() {
    print_header "Creating Environment Configuration"

    # Determine project root (go up two directories from assets/1_gitops)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    INFO_DIR="${PROJECT_ROOT}/info"

    # Create info directory if it doesn't exist
    mkdir -p "${INFO_DIR}"

    print_info "Collecting platform component versions..."

    # Get ArgoCD/GitOps version
    GITOPS_VERSION=$(oc get csv -n ${ARGOCD_NAMESPACE} -o json 2>/dev/null | \
        jq -r '.items[] | select(.spec.displayName | contains("GitOps")) | .spec.displayName + " " + .spec.version' 2>/dev/null | head -1 || echo "N/A")

    # Get RHDH Operator version
    RHDH_OPERATOR_VERSION=$(oc get csv -n rhdh -o json 2>/dev/null | \
        jq -r '.items[] | select(.spec.displayName | contains("Red Hat Developer Hub")) | .spec.displayName + " " + .spec.version' 2>/dev/null | head -1 || echo "N/A")

    # Get AMQ Streams (Kafka) Operator version
    KAFKA_OPERATOR_VERSION=$(oc get csv -n kafka -o json 2>/dev/null | \
        jq -r '.items[] | select(.spec.displayName | contains("Streams for Apache Kafka") or contains("AMQ Streams") or contains("Strimzi")) | .spec.displayName + " " + .spec.version' 2>/dev/null | head -1 || echo "N/A")

    # Get Service Mesh 3 Operator version
    SERVICE_MESH_VERSION=$(oc get csv -n openshift-operators -o jsonpath='{range .items[*]}{.spec.displayName}{" "}{.spec.version}{"\n"}{end}' 2>/dev/null | grep "Red Hat OpenShift Service Mesh 3" | head -1 || echo "N/A")

    # Get Jaeger Operator version
    JAEGER_OPERATOR_VERSION=$(oc get csv -n openshift-operators -o jsonpath='{range .items[*]}{.spec.displayName}{" "}{.spec.version}{"\n"}{end}' 2>/dev/null | grep "Community Jaeger Operator" | head -1 || echo "N/A")

    # Get Elasticsearch ECK Operator version
    ELASTICSEARCH_OPERATOR_VERSION=$(oc get csv -n elastic-system -o jsonpath='{range .items[*]}{.spec.displayName}{" "}{.spec.version}{"\n"}{end}' 2>/dev/null | grep "Elasticsearch (ECK) Operator" | head -1 || echo "N/A")

    # Get Keycloak/RHBK Operator version
    KEYCLOAK_OPERATOR_VERSION=$(oc get csv -n keycloak -o jsonpath='{range .items[*]}{.spec.displayName}{" "}{.spec.version}{"\n"}{end}' 2>/dev/null | grep -E "Red Hat Build of Keycloak|RHBK Operator" | head -1 || echo "N/A")

    # Get Gitea route
    GITEA_ROUTE=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")

    # Get ArgoCD route
    ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n ${ARGOCD_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "N/A")

    # Get Developer Hub route
    RHDH_ROUTE=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "N/A")

    # Create environment_config_platform.md
    cat > "${INFO_DIR}/environment_config_platform.md" <<EOF
# Platform Environment Configuration
**Generated on:** $(date '+%Y-%m-%d %H:%M:%S')

This file contains configuration information for platform components deployed via GitOps.

## Component Versions

\`\`\`
╔═══════════════════════════╦═══════════════════════════════════════════════════════════╗
║ Component                 ║ Version                                                   ║
╠═══════════════════════════╬═══════════════════════════════════════════════════════════╣
║ OpenShift GitOps          ║ ${GITOPS_VERSION}                                         ║
║ Red Hat Developer Hub     ║ ${RHDH_OPERATOR_VERSION}                                  ║
║ Streams for Apache Kafka  ║ ${KAFKA_OPERATOR_VERSION}                                 ║
║ Service Mesh 3            ║ ${SERVICE_MESH_VERSION}                                   ║
║ Jaeger Operator           ║ ${JAEGER_OPERATOR_VERSION}                                ║
║ Elasticsearch (ECK)       ║ ${ELASTICSEARCH_OPERATOR_VERSION}                         ║
║ Keycloak/RHBK             ║ ${KEYCLOAK_OPERATOR_VERSION}                              ║
╚═══════════════════════════╩═══════════════════════════════════════════════════════════╝
\`\`\`

## Platform Services

\`\`\`
╔═══════════════════════════╦═══════════════════════════════════════════════════════════╗
║ Service                   ║ URL                                                       ║
╠═══════════════════════════╬═══════════════════════════════════════════════════════════╣
║ ArgoCD Console            ║ https://${ARGOCD_ROUTE}                                   ║
║ Red Hat Developer Hub     ║ https://${RHDH_ROUTE}                                     ║
║ Gitea                     ║ https://${GITEA_ROUTE}                                    ║
╚═══════════════════════════╩═══════════════════════════════════════════════════════════╝
\`\`\`

## Access Commands

### ArgoCD Console
\`\`\`bash
# Get ArgoCD admin password
oc get secret openshift-gitops-cluster -n ${ARGOCD_NAMESPACE} -o jsonpath='{.data.admin\.password}' | base64 -d && echo

# Access ArgoCD UI
echo "https://${ARGOCD_ROUTE}"
\`\`\`

### Developer Hub
\`\`\`bash
# Get Developer Hub URL
oc get route -n rhdh -o jsonpath='{.items[0].spec.host}' && echo

# Check Developer Hub status
oc get backstage developer-hub -n rhdh
oc get pods -n rhdh
\`\`\`

### Gitea
\`\`\`bash
# Access Gitea
echo "https://${GITEA_ROUTE}"

# Default credentials (from initial setup):
# Username: admin
# Password: gitea1234!
\`\`\`

## ArgoCD Applications

\`\`\`bash
# List all ArgoCD applications
oc get applications -n ${ARGOCD_NAMESPACE}

# Check specific application status
oc get application developer-hub -n ${ARGOCD_NAMESPACE} -o yaml
oc get application kafka-operator -n ${ARGOCD_NAMESPACE} -o yaml
oc get application playground-namespaces -n ${ARGOCD_NAMESPACE} -o yaml
\`\`\`

## Operator Details

### Red Hat Developer Hub Operator
\`\`\`bash
# Check operator status
oc get csv -n rhdh | grep rhdh

# View Backstage custom resource
oc get backstage -n rhdh

# Check operator logs
oc logs -n rhdh deployment/rhdh-operator -f
\`\`\`

### AMQ Streams (Kafka) Operator
\`\`\`bash
# Check operator status
oc get csv -n kafka | grep amq-streams

# List Kafka custom resources
oc get kafka -n kafka

# Check operator logs
oc logs -n kafka deployment/strimzi-cluster-operator -f
\`\`\`

## GitOps Repository

\`\`\`bash
# Repository URL
echo "https://${GITEA_ROUTE}/admin/playground-gitops.git"

# Clone repository (if using HTTPS)
git clone https://${GITEA_ROUTE}/admin/playground-gitops.git

# View repository structure
cd playground-gitops
tree -L 2
\`\`\`

## Troubleshooting

### ArgoCD Application Issues
\`\`\`bash
# Check application sync status
argocd app get <app-name>

# Force sync
argocd app sync <app-name>

# View application logs
oc logs -n ${ARGOCD_NAMESPACE} deployment/openshift-gitops-application-controller
\`\`\`

### Developer Hub Issues
\`\`\`bash
# Check pod status
oc get pods -n rhdh

# View pod logs
oc logs -n rhdh -l app.kubernetes.io/name=backstage

# Check PostgreSQL
oc get pods -n rhdh -l app=postgres
oc logs -n rhdh deployment/postgres
\`\`\`

### Kafka Operator Issues
\`\`\`bash
# Check operator pod
oc get pods -n kafka -l name=strimzi-cluster-operator

# View operator logs
oc logs -n kafka deployment/strimzi-cluster-operator
\`\`\`

## Additional Resources

- OpenShift GitOps Documentation: https://docs.openshift.com/gitops/latest/
- Red Hat Developer Hub Documentation: https://developers.redhat.com/rhdh
- AMQ Streams Documentation: https://access.redhat.com/documentation/en-us/red_hat_amq_streams/
- ArgoCD Official Documentation: https://argo-cd.readthedocs.io/

## Security Notes

**Important:** This configuration file contains cluster-specific information. The default credentials listed are for development/demo purposes only.

### Production Recommendations:
1. Change all default passwords immediately
2. Configure proper authentication (OAuth, SSO, etc.)
3. Enable TLS/HTTPS for all services
4. Implement proper RBAC policies
5. Use secrets management solutions (e.g., External Secrets Operator)
6. Regular security audits and updates

### Changing Default Credentials

For detailed instructions on changing credentials, refer to:
- ArgoCD: Use OpenShift OAuth or update admin password
- Gitea: Change via Gitea admin UI
- Developer Hub: Configure via Backstage app-config

EOF

    print_success "Environment configuration saved to: ${INFO_DIR}/environment_config_platform.md"

    # Append platform operator versions to versions.csv
    print_info "Appending platform operator versions to versions.csv..."

    VERSIONS_FILE="${INFO_DIR}/versions.csv"

    # Check if versions.csv exists
    if [ ! -f "${VERSIONS_FILE}" ]; then
        print_warning "versions.csv not found, creating new file"
        cat > "${VERSIONS_FILE}" <<CSV_HEADER
# This file contains the installed component versions for this environment
# Generated on: $(date '+%Y-%m-%d %H:%M:%S')
component,version
CSV_HEADER
    fi

    # Extract version numbers from the full strings (BSD grep compatible)
    GITOPS_VERSION_NUM=$(echo "$GITOPS_VERSION" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)
    [ "$GITOPS_VERSION_NUM" = "$GITOPS_VERSION" ] && GITOPS_VERSION_NUM="N/A"

    RHDH_VERSION_NUM=$(echo "$RHDH_OPERATOR_VERSION" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)
    [ "$RHDH_VERSION_NUM" = "$RHDH_OPERATOR_VERSION" ] && RHDH_VERSION_NUM="N/A"

    KAFKA_VERSION_NUM=$(echo "$KAFKA_OPERATOR_VERSION" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+-?[0-9]*).*/\1/' | head -1)
    [ "$KAFKA_VERSION_NUM" = "$KAFKA_OPERATOR_VERSION" ] && KAFKA_VERSION_NUM="N/A"

    SERVICE_MESH_VERSION_NUM=$(echo "$SERVICE_MESH_VERSION" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)
    [ "$SERVICE_MESH_VERSION_NUM" = "$SERVICE_MESH_VERSION" ] && SERVICE_MESH_VERSION_NUM="N/A"

    JAEGER_VERSION_NUM=$(echo "$JAEGER_OPERATOR_VERSION" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)
    [ "$JAEGER_VERSION_NUM" = "$JAEGER_OPERATOR_VERSION" ] && JAEGER_VERSION_NUM="N/A"

    ELASTICSEARCH_VERSION_NUM=$(echo "$ELASTICSEARCH_OPERATOR_VERSION" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)
    [ "$ELASTICSEARCH_VERSION_NUM" = "$ELASTICSEARCH_OPERATOR_VERSION" ] && ELASTICSEARCH_VERSION_NUM="N/A"

    KEYCLOAK_VERSION_NUM=$(echo "$KEYCLOAK_OPERATOR_VERSION" | sed -E 's/.*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' | head -1)
    [ "$KEYCLOAK_VERSION_NUM" = "$KEYCLOAK_OPERATOR_VERSION" ] && KEYCLOAK_VERSION_NUM="N/A"

    # Check if entries already exist and remove them (to avoid duplicates)
    if grep -q "^rhdh_operator," "${VERSIONS_FILE}"; then
        # Remove existing RHDH operator entry
        sed -i.bak '/^rhdh_operator,/d' "${VERSIONS_FILE}"
    fi

    if grep -q "^kafka_operator," "${VERSIONS_FILE}"; then
        # Remove existing Kafka operator entry
        sed -i.bak '/^kafka_operator,/d' "${VERSIONS_FILE}"
    fi

    if grep -q "^service_mesh_operator," "${VERSIONS_FILE}"; then
        # Remove existing Service Mesh operator entry
        sed -i.bak '/^service_mesh_operator,/d' "${VERSIONS_FILE}"
    fi

    if grep -q "^jaeger_operator," "${VERSIONS_FILE}"; then
        # Remove existing Jaeger operator entry
        sed -i.bak '/^jaeger_operator,/d' "${VERSIONS_FILE}"
    fi

    if grep -q "^elasticsearch_operator," "${VERSIONS_FILE}"; then
        # Remove existing Elasticsearch operator entry
        sed -i.bak '/^elasticsearch_operator,/d' "${VERSIONS_FILE}"
    fi

    if grep -q "^keycloak_operator," "${VERSIONS_FILE}"; then
        # Remove existing Keycloak operator entry
        sed -i.bak '/^keycloak_operator,/d' "${VERSIONS_FILE}"
    fi

    # Append new entries
    if [ "$RHDH_VERSION_NUM" != "N/A" ]; then
        echo "rhdh_operator,${RHDH_VERSION_NUM}" >> "${VERSIONS_FILE}"
        print_info "Added RHDH operator version: ${RHDH_VERSION_NUM}"
    fi

    if [ "$KAFKA_VERSION_NUM" != "N/A" ]; then
        echo "kafka_operator,${KAFKA_VERSION_NUM}" >> "${VERSIONS_FILE}"
        print_info "Added Kafka operator version: ${KAFKA_VERSION_NUM}"
    fi

    if [ "$SERVICE_MESH_VERSION_NUM" != "N/A" ]; then
        echo "service_mesh_operator,${SERVICE_MESH_VERSION_NUM}" >> "${VERSIONS_FILE}"
        print_info "Added Service Mesh operator version: ${SERVICE_MESH_VERSION_NUM}"
    fi

    if [ "$JAEGER_VERSION_NUM" != "N/A" ]; then
        echo "jaeger_operator,${JAEGER_VERSION_NUM}" >> "${VERSIONS_FILE}"
        print_info "Added Jaeger operator version: ${JAEGER_VERSION_NUM}"
    fi

    if [ "$ELASTICSEARCH_VERSION_NUM" != "N/A" ]; then
        echo "elasticsearch_operator,${ELASTICSEARCH_VERSION_NUM}" >> "${VERSIONS_FILE}"
        print_info "Added Elasticsearch operator version: ${ELASTICSEARCH_VERSION_NUM}"
    fi

    if [ "$KEYCLOAK_VERSION_NUM" != "N/A" ]; then
        echo "keycloak_operator,${KEYCLOAK_VERSION_NUM}" >> "${VERSIONS_FILE}"
        print_info "Added Keycloak operator version: ${KEYCLOAK_VERSION_NUM}"
    fi

    # Clean up backup files
    rm -f "${VERSIONS_FILE}.bak"

    print_success "Versions appended to: ${VERSIONS_FILE}"
}

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

display_summary() {
    print_header "Deployment Summary"

    # Get ArgoCD URL
    ARGOCD_URL=$(oc get route openshift-gitops-server -n ${ARGOCD_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")

    echo "App-of-Apps Pattern Deployed:"
    echo "  Parent App: playground-apps"
    echo "    └─ Manages child applications from apps/ directory in Gitea"
    echo ""
    echo "Child Applications (automatically created by playground-apps):"
    echo "  1. playground-namespaces  - Playground namespace with quotas and policies"
    echo "  2. kafka-operator         - AMQ Streams (Kafka) operator"
    echo "  3. developer-hub          - Red Hat Developer Hub"
    echo ""
    echo "ArgoCD Console:"
    echo "  URL: https://${ARGOCD_URL}"
    echo ""
    echo "Check application status:"
    echo "  oc get applications -n ${ARGOCD_NAMESPACE}"
    echo ""
    echo "View in ArgoCD UI:"
    echo "  1. Open: https://${ARGOCD_URL}"
    echo "  2. Login with OpenShift credentials or admin user"
    echo "  3. View parent app: playground-apps"
    echo "  4. View child apps: playground-namespaces, kafka-operator, developer-hub"
    echo ""
    echo "Monitor sync status:"
    echo "  argocd app get playground-apps"
    echo "  argocd app get playground-namespaces"
    echo "  argocd app get kafka-operator"
    echo "  argocd app get developer-hub"
    echo ""
    echo "Making Changes:"
    echo "  - Edit YAML files in apps/ directory in Gitea"
    echo "  - Commit and push changes to Gitea"
    echo "  - ArgoCD will automatically sync the changes"
    echo ""
    echo "Platform Configuration:"
    echo "  Check info/environment_config_platform.md for component versions and access details"
    echo ""

    print_success "ArgoCD deployment complete!"
}


# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "ArgoCD Application Deployment"

    # Run setup steps
    check_prerequisites
    get_gitea_url
    verify_argocd

    # Deploy using App-of-Apps pattern
    create_playground_app_of_apps

    # Sync applications
    sync_applications

    # Create environment configuration file
    create_environment_config

    # Display summary
    display_summary
}

# Run main function
main
