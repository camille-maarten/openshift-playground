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

    # Create App-of-Apps manifest
    cat > "${TMP_DIR}/playground-app-of-apps.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: playground-apps
  namespace: ${ARGOCD_NAMESPACE}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: .
    directory:
      recurse: false
      include: '*/argocd-application.yaml'

  destination:
    server: https://kubernetes.default.svc
    namespace: ${ARGOCD_NAMESPACE}

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=false
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

    print_info "Applying App-of-Apps manifest..."
    oc apply -f "${TMP_DIR}/playground-app-of-apps.yaml"

    print_success "App-of-Apps created: playground-apps"
}

create_individual_apps() {
    print_header "Creating Individual ArgoCD Applications"

    # Create temporary directory for manifests
    TMP_DIR=$(mktemp -d)
    trap "rm -rf ${TMP_DIR}" EXIT

    # ========================================================================
    # Developer Hub Application
    # ========================================================================

    print_info "Creating Developer Hub application..."

    cat > "${TMP_DIR}/developerhub-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: developer-hub
  namespace: ${ARGOCD_NAMESPACE}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: developerhub/manifests

  destination:
    server: https://kubernetes.default.svc
    namespace: rhdh

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
    - group: rhdh.redhat.com
      kind: Backstage
      jsonPointers:
        - /spec/monitoring
        - /spec/application/imagePullPolicy
        - /spec/application/resources
        - /status
EOF

    oc apply -f "${TMP_DIR}/developerhub-app.yaml"
    print_success "Developer Hub application created"

    # ========================================================================
    # Kafka Application
    # ========================================================================

    print_info "Creating Kafka operator application..."

    cat > "${TMP_DIR}/kafka-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kafka-operator
  namespace: ${ARGOCD_NAMESPACE}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: kafka/manifests

  destination:
    server: https://kubernetes.default.svc
    namespace: kafka

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

    oc apply -f "${TMP_DIR}/kafka-app.yaml"
    print_success "Kafka operator application created"

    # ========================================================================
    # Namespaces Application
    # ========================================================================

    print_info "Creating namespaces application..."

    cat > "${TMP_DIR}/namespaces-app.yaml" <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: playground-namespaces
  namespace: ${ARGOCD_NAMESPACE}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: ${REPO_URL}
    targetRevision: main
    path: namespaces/manifests

  destination:
    server: https://kubernetes.default.svc
    namespace: default

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=false
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
EOF

    oc apply -f "${TMP_DIR}/namespaces-app.yaml"
    print_success "Namespaces application created"
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
# DISPLAY SUMMARY
# ============================================================================

display_summary() {
    print_header "Deployment Summary"

    # Get ArgoCD URL
    ARGOCD_URL=$(oc get route openshift-gitops-server -n ${ARGOCD_NAMESPACE} -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")

    echo "ArgoCD Applications Created:"
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
    echo "  3. View applications: playground-namespaces, kafka-operator, developer-hub"
    echo ""
    echo "Monitor sync status:"
    echo "  argocd app get playground-namespaces"
    echo "  argocd app get kafka-operator"
    echo "  argocd app get developer-hub"
    echo ""

    print_success "ArgoCD deployment complete!"
}

# ============================================================================
# PROMPT USER FOR DEPLOYMENT CHOICE
# ============================================================================

prompt_deployment_choice() {
    print_header "Deployment Options"

    echo "Choose deployment approach:"
    echo "  1. Individual Applications (Recommended)"
    echo "     - Creates separate ArgoCD apps for each component"
    echo "     - More control over individual components"
    echo "     - Easier to manage and troubleshoot"
    echo ""
    echo "  2. App-of-Apps Pattern"
    echo "     - Single parent app that manages all child apps"
    echo "     - Requires argocd-application.yaml in each component"
    echo "     - More advanced GitOps pattern"
    echo ""

    read -p "Select option (1/2) [1]: " DEPLOY_OPTION
    DEPLOY_OPTION=${DEPLOY_OPTION:-1}

    case $DEPLOY_OPTION in
        1)
            print_info "Using Individual Applications approach"
            DEPLOY_MODE="individual"
            ;;
        2)
            print_info "Using App-of-Apps pattern"
            DEPLOY_MODE="app-of-apps"
            ;;
        *)
            print_warning "Invalid option, defaulting to Individual Applications"
            DEPLOY_MODE="individual"
            ;;
    esac
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
    prompt_deployment_choice

    # Deploy based on selected mode
    if [ "$DEPLOY_MODE" == "app-of-apps" ]; then
        create_playground_app_of_apps
    else
        create_individual_apps
    fi

    # Sync applications
    sync_applications

    # Display summary
    display_summary
}

# Run main function
main
