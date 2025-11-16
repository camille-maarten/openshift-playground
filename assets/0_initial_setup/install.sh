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

# ============================================================================
# PRE-INSTALLATION CHECKS
# ============================================================================

print_info "==================================================================="
print_info "  PRE-INSTALLATION VALIDATION"
print_info "==================================================================="
echo ""

# Check if 15-gitlab-user-password-secret.yaml exists
if [ ! -f "manifests/15-gitlab-user-password-secret.yaml" ]; then
    print_error "SETUP REQUIRED: GitLab user configuration file is missing!"
    echo ""
    echo "You need to create the GitLab user configuration file before installation."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "STEP 1: Copy the template file"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Run this command to copy the template:"
    echo ""
    echo "  cp manifests/15-gitlab-user-password-secret.yaml.template manifests/15-gitlab-user-password-secret.yaml"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "STEP 2: Add your SSH public key (OPTIONAL - for Git access)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "If you want to use SSH to clone GitLab repositories:"
    echo ""
    echo "a) Check if you have an SSH key already:"
    echo "   ls ~/.ssh/id_*.pub"
    echo ""
    echo "b) If you DON'T have one, create it:"
    echo "   ssh-keygen -t ed25519 -C \"your-email@example.com\" -f ~/.ssh/id_ed25519"
    echo "   (Just press ENTER for all prompts to accept defaults)"
    echo ""
    echo "c) Display your public key:"
    echo "   cat ~/.ssh/id_ed25519.pub"
    echo ""
    echo "d) Copy the output (it starts with 'ssh-ed25519 ...')"
    echo ""
    echo "e) Open the file for editing:"
    echo "   vim manifests/15-gitlab-user-password-secret.yaml"
    echo "   (or use: nano, code, or any text editor)"
    echo ""
    echo "f) Find this line in the file:"
    echo "   # ssh_public_key: ssh-ed25519 AAAA... your-email@example.com"
    echo ""
    echo "g) Remove the '#' and replace with YOUR public key:"
    echo "   ssh_public_key: ssh-ed25519 AAAA... your-email@example.com"
    echo ""
    echo "h) Save and exit (in vim: press ESC, then type :wq and press ENTER)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "ALTERNATIVE: Skip SSH key (use HTTPS only)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "If you only want to use HTTPS (with username/password), just copy"
    echo "the template without adding an SSH key. You can add it later."
    echo ""
    echo "  cp manifests/15-gitlab-user-password-secret.yaml.template manifests/15-gitlab-user-password-secret.yaml"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_info "After completing the steps above, run this script again:"
    echo "  ./install.sh"
    echo ""
    exit 1
fi

print_info "✓ GitLab user configuration file found"
echo ""

print_info "==================================================================="
print_info "  INSTALLATION SUMMARY"
print_info "==================================================================="
echo ""
print_info "This installation will:"
echo "  - Install ArgoCD with OpenShift GitOps"
echo "  - Install GitLab Community Edition"
echo "  - Automatically configure ArgoCD to use the local GitLab instance"
echo ""
print_info "Default credentials:"
echo "  - ArgoCD admin: admin / argo1234!"
echo "  - GitLab root: root / gitlab1234!"
echo ""

# Confirm installation
echo "This script will install:"
echo "  1. Red Hat OpenShift GitOps (ArgoCD)"
echo "  2. GitLab Community Edition"
echo ""
read -p "Do you want to proceed with the installation? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Installation cancelled."
    exit 0
fi

echo ""
print_info "==================================================================="
print_info "  PART 1: Installing Red Hat OpenShift GitOps (ArgoCD)"
print_info "==================================================================="
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

# Apply ConfigMaps
print_info "Applying ConfigMaps..."
oc apply -f manifests/05-argocd-repositories-configmap.yaml
oc apply -f manifests/06-argocd-cm-configmap.yaml
oc apply -f manifests/07-argocd-rbac-configmap.yaml

echo ""
print_info "ArgoCD installation complete!"
echo ""

# Show pod status
print_info "Current pod status:"
oc get pods -n openshift-gitops

echo ""
echo ""
print_info "==================================================================="
print_info "  PART 2: Installing GitLab Community Edition"
print_info "==================================================================="
echo ""

# Step 6: Create GitLab namespace
print_info "Step 6/11: Creating GitLab namespace..."
oc apply -f manifests/11-gitlab-namespace.yaml
sleep 3

# Step 7: Create GitLab OperatorGroup
print_info "Step 7/11: Creating GitLab OperatorGroup..."
oc apply -f manifests/12-gitlab-operatorgroup.yaml
sleep 2

# Step 8: Install GitLab operator
print_info "Step 8/11: Installing GitLab Operator..."
oc apply -f manifests/13-gitlab-subscription.yaml

print_info "Waiting for GitLab operator to be installed (this may take 2-5 minutes)..."
sleep 15

# Wait for GitLab operator to be ready
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if oc get csv -n gitlab-system 2>/dev/null | grep -q "Succeeded"; then
        print_info "GitLab Operator installed successfully!"
        break
    fi
    echo -n "."
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    print_error "GitLab Operator installation timed out. Please check the status manually."
    echo "Run: oc get csv -n gitlab-system"
    exit 1
fi

echo ""
sleep 5

# Step 9: Apply GitLab secrets
print_info "Step 9/12: Applying GitLab secrets..."
oc apply -f manifests/14-gitlab-root-password-secret.yaml
oc apply -f manifests/15-gitlab-user-password-secret.yaml
oc apply -f manifests/19-gitlab-minio-secret.yaml
sleep 2

# Step 10: Apply GitLab ConfigMap
print_info "Step 10/12: Applying GitLab ConfigMap..."
oc apply -f manifests/17-gitlab-configmap.yaml
sleep 2

# Step 11: Deploy GitLab instance
print_info "Step 11/12: Deploying GitLab instance (this may take 5-10 minutes)..."
oc apply -f manifests/16-gitlab-instance.yaml
sleep 10

print_info "GitLab is being deployed. This can take several minutes..."
print_info "You can monitor the progress with: oc get pods -n gitlab-system -w"

# Optionally apply routes
print_info "Applying GitLab routes..."
oc apply -f manifests/18-gitlab-route.yaml 2>/dev/null || print_warning "Routes may need to be configured after GitLab pods are ready"

echo ""
sleep 5

# Step 12: Auto-configure ArgoCD to use GitLab
print_info "Step 12/12: Configuring ArgoCD to use local GitLab..."

# Create a secret for ArgoCD to access GitLab
cat <<EOF | oc apply -f -
---
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-repo-credentials
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://gitlab-webservice-default.gitlab-system.svc.cluster.local
  password: gitlab1234!
  username: root
  insecure: "true"
  enableLfs: "true"
EOF

print_info "ArgoCD has been configured to use the local GitLab instance"
print_info "You can now create repositories in GitLab and they will be accessible to ArgoCD"

echo ""
echo ""
print_info "==================================================================="
print_info "  Installation Summary"
print_info "==================================================================="
echo ""

# Get ArgoCD URL
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not yet available")

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
echo ""
echo "=========================================="
echo ""

# Get GitLab URL
GITLAB_ROUTE=$(oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not yet available")

echo "=========================================="
echo "GitLab Access Information"
echo "=========================================="
echo ""
echo "GitLab URL: https://${GITLAB_ROUTE}"
echo ""
echo "Note: GitLab may take 5-10 minutes to fully deploy"
echo ""
echo "Root Login:"
echo "  - Username: root"
echo "  - Password: gitlab1234!"
echo ""
echo "To check GitLab deployment status:"
echo "  oc get pods -n gitlab-system"
echo "  oc get gitlab -n gitlab-system"
echo ""
echo "=========================================="
echo ""

print_info "Installation complete!"
echo ""
print_info "Next steps:"
echo "  1. Wait for all GitLab pods to be running (check with: oc get pods -n gitlab-system)"
echo "  2. Access ArgoCD UI and configure your first application"
echo "  3. Access GitLab UI and create your first project"
echo "  4. Integrate GitLab with ArgoCD for GitOps workflows"
echo ""
print_info "For more information, see README.md"
