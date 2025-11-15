#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if oc is installed
if ! command -v oc &> /dev/null; then
    print_error "oc CLI is not installed. Please install it first."
    exit 1
fi

# Check if user is logged in
if ! oc whoami &> /dev/null; then
    print_error "You are not logged in to OpenShift. Please run 'oc login' first."
    echo ""
    echo "To get your login command:"
    echo "1. Open OpenShift Web Console"
    echo "2. Click your username in top-right corner"
    echo "3. Select 'Copy login command'"
    echo "4. Click 'Display Token'"
    echo "5. Copy and run the 'oc login' command"
    exit 1
fi

print_info "Logged in as: $(oc whoami)"
print_info "Current cluster: $(oc whoami --show-server)"
echo ""

# Check if required secret files exist
print_info "Checking for required secret files..."
MISSING_SECRETS=0

if [ ! -f "manifests/08-git-credentials-secret.yaml" ]; then
    print_error "Missing: manifests/08-git-credentials-secret.yaml"
    echo "  This file is required for Git repository authentication."
    echo "  Steps to create it:"
    echo "    1. Copy the template: cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml"
    echo "    2. Edit the file and add your Git credentials"
    echo "    3. Run this script again"
    echo ""
    MISSING_SECRETS=1
fi

if [ ! -f "manifests/09-webhook-secret.yaml" ]; then
    print_error "Missing: manifests/09-webhook-secret.yaml"
    echo "  This file is required for webhook integration and notifications."
    echo "  Steps to create it:"
    echo "    1. Copy the template: cp manifests/09-webhook-secret.yaml.template manifests/09-webhook-secret.yaml"
    echo "    2. Edit the file and add your webhook secrets"
    echo "    3. Run this script again"
    echo ""
    MISSING_SECRETS=1
fi

if [ $MISSING_SECRETS -eq 1 ]; then
    echo ""
    print_error "Please create the required secret files before proceeding."
    echo "Alternatively, if you want to skip secrets for now, you can:"
    echo "  1. Create empty placeholder files:"
    echo "     touch manifests/08-git-credentials-secret.yaml"
    echo "     touch manifests/09-webhook-secret.yaml"
    echo "  2. Configure secrets later via ArgoCD UI or CLI"
    exit 1
fi

print_info "All required secret files found."
echo ""

# Confirm installation
read -p "Do you want to install Red Hat OpenShift GitOps? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Installation cancelled."
    exit 0
fi

print_info "Starting Red Hat OpenShift GitOps installation..."
echo ""

# Step 1: Create namespace
print_info "Step 1/5: Creating namespace..."
oc apply -f manifests/01-namespace.yaml
sleep 3

# Step 2: Create OperatorGroup
print_info "Step 2/5: Creating OperatorGroup..."
oc apply -f manifests/02-operatorgroup.yaml
sleep 2

# Step 3: Install operator
print_info "Step 3/5: Installing Red Hat GitOps Operator..."
oc apply -f manifests/03-subscription.yaml

print_info "Waiting for operator to be installed (this may take 2-5 minutes)..."
sleep 15

# Wait for operator to be ready
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if oc get csv -n openshift-gitops 2>/dev/null | grep -q "Succeeded"; then
        print_info "Operator installed successfully!"
        break
    fi
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_error "Operator installation timed out. Please check the status manually."
    echo "Run: oc get csv -n openshift-gitops"
    exit 1
fi

echo ""
sleep 5

# Step 4: Apply admin password secret
print_info "Step 4/5: Applying admin password secret..."
oc apply -f manifests/10-admin-password-secret.yaml
sleep 2

# Step 5: Deploy ArgoCD instance
print_info "Step 5/5: Deploying ArgoCD instance..."
oc apply -f manifests/04-argocd-instance.yaml

print_info "Waiting for ArgoCD to be ready (this may take 3-5 minutes)..."
sleep 30

# Wait for ArgoCD pods to be ready
print_info "Waiting for all ArgoCD pods to be running..."
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    READY_PODS=$(oc get pods -n openshift-gitops --no-headers 2>/dev/null | grep -v "Completed" | grep "Running" | wc -l)
    TOTAL_PODS=$(oc get pods -n openshift-gitops --no-headers 2>/dev/null | grep -v "Completed" | wc -l)

    if [ "$READY_PODS" -ge 5 ] && [ "$TOTAL_PODS" -ge 5 ]; then
        print_info "All ArgoCD pods are running!"
        break
    fi
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_warning "Some pods may not be ready yet. Please check the status manually."
    echo "Run: oc get pods -n openshift-gitops"
fi

echo ""
sleep 5

# Apply ConfigMaps and Secrets
print_info "Applying ConfigMaps and Secrets..."
oc apply -f manifests/05-argocd-repositories-configmap.yaml
oc apply -f manifests/06-argocd-cm-configmap.yaml
oc apply -f manifests/07-argocd-rbac-configmap.yaml
oc apply -f manifests/08-git-credentials-secret.yaml
oc apply -f manifests/09-webhook-secret.yaml

echo ""
print_info "Installation complete!"
echo ""

# Get ArgoCD URL and credentials
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "Route not found")

echo "=========================================="
echo "ArgoCD Access Information"
echo "=========================================="
echo ""
echo "ArgoCD URL: https://${ARGOCD_ROUTE}"
echo ""
echo "Login Options:"
echo "1. OpenShift OAuth (Recommended):"
echo "   - Click 'Log in via OpenShift' on the ArgoCD login page"
echo "   - Use your OpenShift credentials"
echo ""
echo "2. Admin User:"
echo "   - Username: admin"
echo "   - Password: argo1234!"
echo "   - (This is the default password set in manifests/10-admin-password-secret.yaml)"
echo ""
echo "=========================================="
echo ""

# Show pod status
print_info "Current pod status:"
oc get pods -n openshift-gitops

echo ""
print_info "To verify the installation, run:"
echo "  oc get argocd -n openshift-gitops"
echo "  oc get pods -n openshift-gitops"
echo ""
print_info "For more information, see README.md"
