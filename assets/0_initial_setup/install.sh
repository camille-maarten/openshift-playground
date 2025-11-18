#!/bin/bash

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

# Gitea Helm Chart Configuration
GITEA_CHART_VERSION="12.4.0"
GITEA_CHART_REPO="https://dl.gitea.com/charts/"
GITEA_CHART_REPO_NAME="gitea-charts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    printf "${GREEN}[INFO]${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}[WARNING]${NC} %s\n" "$1"
}

print_success() {
    printf "${GREEN}[SUCCESS]${NC} %s\n" "$1"
}

# ============================================================================
# ENSURE WE'RE IN THE CORRECT DIRECTORY
# ============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
INFO_DIR="${PROJECT_ROOT}/info"

# Remove old environment files if they exist
if [ -f "${INFO_DIR}/environment_config.md" ]; then
    print_info "Removing old environment configuration file..."
    rm -f "${INFO_DIR}/environment_config.md"
fi

if [ -f "${INFO_DIR}/versions.csv" ]; then
    print_info "Removing old versions file..."
    rm -f "${INFO_DIR}/versions.csv"
fi

# Change to the script directory
cd "$SCRIPT_DIR"

print_info "Working directory: $SCRIPT_DIR"
echo ""

# Check if oc is installed
if ! command -v oc &> /dev/null; then
    print_error "oc CLI is not installed. Please install it first."
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed. Please install it first."
    echo ""
    echo "Install Helm:"
    echo "  macOS:  brew install helm"
    echo "  Linux:  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
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
# INSTALLATION OPTIONS
# ============================================================================

print_info "==================================================================="
print_info "  OpenShift GitOps Setup - Installation Options"
print_info "==================================================================="
echo ""

echo "This script will install:"
echo "  1. Red Hat OpenShift GitOps (ArgoCD)"
echo "  2. Gitea (lightweight Git server) OR use external GitHub"
echo ""

# Ask about Git server option
echo "Git Server Options:"
echo "  1. Install Gitea (local Git server on OpenShift)"
echo "  2. Use external GitHub repository"
echo "  3. Skip Git server (ArgoCD only)"
echo ""

read -p "Select option (1/2/3) [1]: " GIT_OPTION
GIT_OPTION=${GIT_OPTION:-1}

INSTALL_GITEA=false
USE_GITHUB=false

case $GIT_OPTION in
    1)
        INSTALL_GITEA=true
        print_info "Will install Gitea locally"
        ;;
    2)
        USE_GITHUB=true
        print_info "Will configure GitHub integration"

        echo ""
        echo "GitHub Configuration:"
        read -p "Enter GitHub organization or username: " GITHUB_ORG
        read -p "Enter GitHub repository name (or leave empty for multiple repos): " GITHUB_REPO
        read -p "Enter GitHub Personal Access Token: " -s GITHUB_TOKEN
        echo ""

        if [ -z "$GITHUB_ORG" ] || [ -z "$GITHUB_TOKEN" ]; then
            print_error "GitHub organization and token are required"
            exit 1
        fi
        ;;
    3)
        print_info "Skipping Git server installation"
        ;;
    *)
        print_error "Invalid option"
        exit 1
        ;;
esac

echo ""
print_info "==================================================================="
print_info "  INSTALLATION SUMMARY"
print_info "==================================================================="
echo ""

print_info "This installation will:"
echo "  - Install Red Hat OpenShift GitOps (ArgoCD)"
if [ "$INSTALL_GITEA" = true ]; then
    echo "  - Install Gitea Git server"
elif [ "$USE_GITHUB" = true ]; then
    echo "  - Configure GitHub integration for: $GITHUB_ORG"
    [ -n "$GITHUB_REPO" ] && echo "    Repository: $GITHUB_REPO"
fi
echo ""
print_info "Default ArgoCD credentials:"
echo "  - admin / argocd1234!"
echo "  - admin-user / argocd1234!"
echo ""

# ============================================================================
# PART 1: Installing Red Hat OpenShift GitOps (ArgoCD)
# ============================================================================

echo ""
print_info "==================================================================="
print_info "  PART 1: Installing Red Hat OpenShift GitOps (ArgoCD)"
print_info "==================================================================="
echo ""

print_info "Step 1/5: Creating namespace..."
oc apply -f manifests/01-namespace.yaml

print_info "Step 2/5: Creating OperatorGroup..."
oc apply -f manifests/02-operatorgroup.yaml

print_info "Step 3/5: Installing Red Hat GitOps Operator..."
oc apply -f manifests/03-subscription.yaml

print_info "Waiting for operator to be installed (this may take 2-5 minutes)..."
sleep 30

# Wait for the operator to be ready
TIMEOUT=300
ELAPSED=0
while ! oc get csv -n openshift-gitops | grep -q "openshift-gitops-operator.*Succeeded"; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        print_error "Timeout waiting for operator installation"
        exit 1
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

print_info "Operator installed successfully!"
echo ""

print_info "Step 4/5: Applying admin password secret..."
oc apply -f manifests/10-admin-password-secret.yaml

print_info "Step 5/5: Deploying ArgoCD instance..."
oc apply -f manifests/04-argocd-instance.yaml

print_info "Waiting for ArgoCD to be ready (this may take 3-5 minutes)..."
sleep 30

# Wait for ArgoCD server to be ready
print_info "Waiting for all ArgoCD pods to be running..."
TIMEOUT=300
ELAPSED=0
while true; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        print_error "Timeout waiting for ArgoCD pods"
        exit 1
    fi

    PENDING=$(oc get pods -n openshift-gitops --no-headers 2>/dev/null | grep -v Running | grep -v Completed | wc -l || echo "1")
    if [ "$PENDING" -eq "0" ]; then
        break
    fi

    sleep 10
    ELAPSED=$((ELAPSED + 10))
done

print_info "All ArgoCD pods are running!"
echo ""

print_info "Applying ConfigMaps..."
oc apply -f manifests/05-argocd-repositories-configmap.yaml
# Note: 06-argocd-cm-configmap.yaml is managed by the ArgoCD operator via extraConfig in the ArgoCD CR
# Applying it manually would conflict with operator management
oc apply -f manifests/07-argocd-rbac-configmap.yaml

print_info "Ensuring admin-user password is set..."
oc apply -f manifests/10-admin-password-secret.yaml

print_info "Restarting ArgoCD server pods to pick up configuration changes..."
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops

print_info "Waiting for ArgoCD server to restart..."
sleep 15
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops --timeout=360s

print_info "ArgoCD installation complete!"
echo ""

print_info "Current pod status:"
oc get pods -n openshift-gitops
echo ""

ARGOCD_URL=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "not-available")
print_info "ArgoCD Access Information:"
echo "  URL: https://${ARGOCD_URL}"
echo "  Login with one of these accounts:"
echo "    - admin / argocd1234!"
echo "    - admin-user / argocd1234!"
echo ""

# ============================================================================
# PART 2: Installing Gitea (if selected)
# ============================================================================

if [ "$INSTALL_GITEA" = true ]; then
    echo ""
    print_info "==================================================================="
    print_info "  PART 2: Installing Gitea Git Server"
    print_info "==================================================================="
    echo ""

    # Check if Gitea is already installed
    if helm list -n gitea 2>/dev/null | grep -q gitea; then
        print_warning "Gitea is already installed. Uninstalling to ensure clean installation..."
        helm uninstall gitea -n gitea --wait 2>/dev/null || true
        print_info "Waiting for Gitea pods to terminate..."
        sleep 10

        # Optionally delete PVCs to start fresh
        print_warning "Deleting Gitea persistent volume claims for fresh installation..."
        oc delete pvc --all -n gitea 2>/dev/null || true
        sleep 5
    fi

    print_info "Step 1/5: Adding Gitea Helm repository..."
    helm repo add ${GITEA_CHART_REPO_NAME} ${GITEA_CHART_REPO} 2>/dev/null || true
    helm repo update

    print_info "Step 2/5: Creating gitea namespace..."
    oc create namespace gitea 2>/dev/null || oc project gitea

    print_info "Step 3/5: Configuring OpenShift security..."
    # Grant anyuid SCC to service accounts for Gitea compatibility
    oc adm policy add-scc-to-user anyuid -z gitea -n gitea 2>/dev/null || true
    oc adm policy add-scc-to-user anyuid -z default -n gitea 2>/dev/null || true

    print_info "Step 4/5: Getting cluster domain..."
    CLUSTER_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}' 2>/dev/null || echo "apps.example.com")
    print_info "Using domain: ${CLUSTER_DOMAIN}"

    print_info "Step 5/5: Creating Gitea values file..."
    cat > /tmp/gitea-values.yaml <<EOF
gitea:
  admin:
    username: admin
    password: gitea1234!
    email: admin@gitea.local

  config:
    server:
      DOMAIN: gitea-http.gitea.svc.cluster.local
      ROOT_URL: https://gitea-gitea.${CLUSTER_DOMAIN}/
      DISABLE_SSH: false
      SSH_DOMAIN: gitea-ssh.gitea.svc.cluster.local
      SSH_PORT: 22

    database:
      DB_TYPE: sqlite3

    security:
      INSTALL_LOCK: true

    service:
      DISABLE_REGISTRATION: false

service:
  http:
    type: ClusterIP
    port: 3000
  ssh:
    type: ClusterIP
    port: 22

ingress:
  enabled: false

persistence:
  enabled: true
  size: 10Gi

postgresql:
  enabled: false

redis-cluster:
  enabled: false
EOF

    print_info "Step 6/6: Installing Gitea via Helm (version ${GITEA_CHART_VERSION})..."
    helm upgrade --install gitea ${GITEA_CHART_REPO_NAME}/gitea \
      --version ${GITEA_CHART_VERSION} \
      --namespace gitea \
      --values /tmp/gitea-values.yaml \
      --wait \
      --timeout 600s || print_warning "Gitea installation initiated. Check status with: oc get pods -n gitea"

    print_info "Creating OpenShift route for Gitea..."
    oc create route edge gitea \
      --service=gitea-http \
      --port=http \
      -n gitea 2>/dev/null || print_warning "Route may already exist"

    GITEA_URL=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}' 2>/dev/null || echo "gitea-gitea.${CLUSTER_DOMAIN}")

    print_info "Gitea installation complete!"
    echo ""

    print_info "Configuring ArgoCD to use Gitea..."
    cat > /tmp/gitea-repo-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitea-repo-credentials
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://${GITEA_URL}
  password: gitea1234!
  username: admin
  insecure: "false"
EOF

    oc apply -f /tmp/gitea-repo-secret.yaml
    rm -f /tmp/gitea-repo-secret.yaml

    print_info "ArgoCD configured to use Gitea!"
fi

# ============================================================================
# PART 3: Configuring GitHub Integration (if selected)
# ============================================================================

if [ "$USE_GITHUB" = true ]; then
    echo ""
    print_info "==================================================================="
    print_info "  PART 3: Configuring GitHub Integration"
    print_info "==================================================================="
    echo ""

    if [ -n "$GITHUB_REPO" ]; then
        # Single repository
        GITHUB_URL="https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
        print_info "Configuring single repository: $GITHUB_URL"

        cat > /tmp/github-repo-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: github-repo-${GITHUB_REPO}
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: ${GITHUB_URL}
  password: ${GITHUB_TOKEN}
  username: ${GITHUB_ORG}
EOF
    else
        # Organization-wide credentials
        GITHUB_URL="https://github.com/${GITHUB_ORG}"
        print_info "Configuring organization-wide access: $GITHUB_URL"

        cat > /tmp/github-repo-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: github-org-${GITHUB_ORG}
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: ${GITHUB_URL}
  password: ${GITHUB_TOKEN}
  username: ${GITHUB_ORG}
EOF
    fi

    oc apply -f /tmp/github-repo-secret.yaml
    rm -f /tmp/github-repo-secret.yaml

    print_info "GitHub integration configured!"
    print_info "You can now create ArgoCD applications using repositories from: $GITHUB_ORG"
fi

# ============================================================================
# Installation Summary
# ============================================================================

echo ""
print_info "==================================================================="
print_info "  Installation Summary"
print_info "==================================================================="
echo ""

# Get ArgoCD URL and versions
ARGOCD_URL=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available yet")
ARGOCD_OPERATOR_VERSION=$(oc get csv -n openshift-gitops 2>/dev/null | grep openshift-gitops-operator | awk '{print $1}' | cut -d'v' -f2 || echo "Unknown")

# Get ArgoCD core version from the running pod
ARGOCD_POD=$(oc get pod -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$ARGOCD_POD" ]; then
    ARGOCD_CORE_VERSION=$(oc exec -n openshift-gitops $ARGOCD_POD -- argocd version --client --short 2>/dev/null | head -1 | awk '{print $2}' || echo "Unknown")
else
    ARGOCD_CORE_VERSION="Unknown"
fi

# Get Gitea versions if installed
if [ "$INSTALL_GITEA" = true ]; then
    GITEA_APP_VERSION=$(helm list -n gitea -o json 2>/dev/null | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['app_version'] if data else 'Unknown')" 2>/dev/null || echo "Unknown")
    GITEA_HELM_CHART_VERSION=$(helm list -n gitea -o json 2>/dev/null | python3 -c "import sys, json; data = json.load(sys.stdin); print(data[0]['chart'].split('-')[-1] if data else 'Unknown')" 2>/dev/null || echo "Unknown")
fi

echo "=========================================="
echo "ArgoCD Access Information"
echo "=========================================="
echo ""
echo "ArgoCD URL: https://${ARGOCD_URL}"
echo "OpenShift GitOps Operator Version: ${ARGOCD_OPERATOR_VERSION}"
echo "ArgoCD Core Version: ${ARGOCD_CORE_VERSION}"
echo ""
echo "Login Options:"
echo "1. OpenShift OAuth (Recommended):"
echo "   - Click 'Log in via OpenShift' on the ArgoCD login page"
echo "   - Use your OpenShift credentials"
echo ""
echo "2. Admin User:"
echo "   - Username: admin"
echo "   - Password: argocd1234!"
echo ""
echo "=========================================="
echo ""

if [ "$INSTALL_GITEA" = true ]; then
    echo "=========================================="
    echo "Gitea Access Information"
    echo "=========================================="
    echo ""
    echo "Gitea URL: https://${GITEA_URL}"
    echo "Gitea Application Version: ${GITEA_APP_VERSION}"
    echo "Helm Chart Version: ${GITEA_HELM_CHART_VERSION}"
    echo "Chart Repository: ${GITEA_CHART_REPO}"
    echo ""
    echo "Admin Login:"
    echo "  - Username: admin"
    echo "  - Password: gitea1234!"
    echo ""
    echo "To check Gitea deployment status:"
    echo "  oc get pods -n gitea"
    echo "  helm list -n gitea"
    echo ""
    echo "=========================================="
    echo ""
fi

if [ "$USE_GITHUB" = true ]; then
    echo "=========================================="
    echo "GitHub Integration"
    echo "=========================================="
    echo ""
    echo "GitHub Organization: $GITHUB_ORG"
    if [ -n "$GITHUB_REPO" ]; then
        echo "Repository: $GITHUB_REPO"
    else
        echo "Access: All repositories in organization"
    fi
    echo ""
    echo "Create ArgoCD applications using:"
    if [ -n "$GITHUB_REPO" ]; then
        echo "  Repository URL: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
    else
        echo "  Repository URL: https://github.com/${GITHUB_ORG}/<your-repo>"
    fi
    echo ""
    echo "=========================================="
    echo ""
fi

print_info "Installation complete!"
echo ""

# Print credentials summary table
echo "╔═══════════════════════════════════════════════════════════════════════════════════╗"
echo "║                          ACCESS CREDENTIALS SUMMARY                               ║"
echo "╠═══════════════╦═══════════════════════════════════════════════════════════════════╣"
echo "║ Service       ║ Details                                                           ║"
echo "╠═══════════════╬═══════════════════════════════════════════════════════════════════╣"
echo "║ ArgoCD        ║                                                                   ║"
echo "║               ║ Operator Version: ${ARGOCD_OPERATOR_VERSION}                      "
echo "║               ║ Core Version:     ${ARGOCD_CORE_VERSION}                          "
echo "║               ║ Route:    https://${ARGOCD_URL}"
echo "║               ║ Username: admin                                                   ║"
echo "║               ║ Password: argocd1234!                                            ║"
echo "║               ║ (or use 'Log in via OpenShift')                                   ║"

if [ "$INSTALL_GITEA" = true ]; then
    echo "╠═══════════════╬═══════════════════════════════════════════════════════════════════╣"
    echo "║ Gitea         ║                                                                   ║"
    echo "║               ║ App Version:   ${GITEA_APP_VERSION}                               "
    echo "║               ║ Chart Version: ${GITEA_HELM_CHART_VERSION}                        "
    echo "║               ║ Chart Repo:    ${GITEA_CHART_REPO}                                "
    echo "║               ║ Route:         https://${GITEA_URL}"
    echo "║               ║ Username:      admin                                              ║"
    echo "║               ║ Password:      gitea1234!                                         ║"
fi

if [ "$USE_GITHUB" = true ]; then
    echo "╠═══════════════╬═══════════════════════════════════════════════════════════════════╣"
    echo "║ GitHub        ║                                                                   ║"
    echo "║               ║ Organization: ${GITHUB_ORG}                                       "
    if [ -n "$GITHUB_REPO" ]; then
        echo "║               ║ Repository:   ${GITHUB_REPO}                                      "
    else
        echo "║               ║ Access: All repositories in organization                          ║"
    fi
fi

echo "╚═══════════════╩═══════════════════════════════════════════════════════════════════╝"
echo ""

print_info "Next steps:"
echo "  1. Access ArgoCD UI at: https://${ARGOCD_URL}"
echo "  2. Login with admin / argocd1234! or use OpenShift OAuth"

if [ "$INSTALL_GITEA" = true ]; then
    echo "  3. Access Gitea at: https://${GITEA_URL}"
    echo "  4. Create your first repository in Gitea"
    echo "  5. Create your first ArgoCD application pointing to Gitea"
elif [ "$USE_GITHUB" = true ]; then
    echo "  3. Create your first ArgoCD application pointing to your GitHub repository"
else
    echo "  3. Configure a Git repository connection in ArgoCD"
    echo "  4. Create your first ArgoCD application"
fi

echo ""
print_info "Verification commands:"
echo "  • ArgoCD status: oc get pods -n openshift-gitops"
if [ "$INSTALL_GITEA" = true ]; then
    echo "  • Gitea status:  oc get pods -n gitea"
fi
echo ""
print_info "For troubleshooting, see the documentation in assets/0_initial_setup/"

# Create environment_config.md and versions.csv with actual values
print_info "Creating environment configuration files..."
mkdir -p "${INFO_DIR}"

# Create versions.csv
cat > "${INFO_DIR}/versions.csv" <<EOF
# This file contains the installed component versions for this environment
# Generated on: $(date '+%Y-%m-%d %H:%M:%S')
component,version
argocd_operator,${ARGOCD_OPERATOR_VERSION}
argocd_core,${ARGOCD_CORE_VERSION}
EOF

# Append Gitea version if installed
if [ "$INSTALL_GITEA" = true ]; then
    echo "gitea_app,${GITEA_APP_VERSION}" >> "${INFO_DIR}/versions.csv"
    echo "gitea_chart,${GITEA_HELM_CHART_VERSION}" >> "${INFO_DIR}/versions.csv"
fi

# Create environment_config.md
cat > "${INFO_DIR}/environment_config.md" <<EOF
# Environment Configuration

This file contains the access credentials and configuration details for your OpenShift GitOps environment.

**Generated on**: $(date '+%Y-%m-%d %H:%M:%S')

## Access Credentials Summary

\`\`\`
╔═══════════════════════════════════════════════════════════════════════════════════╗
║                          ACCESS CREDENTIALS SUMMARY                               ║
╠═══════════════╦═══════════════════════════════════════════════════════════════════╣
║ Service       ║ Details                                                           ║
╠═══════════════╬═══════════════════════════════════════════════════════════════════╣
║ ArgoCD        ║                                                                   ║
║               ║ Operator Version: ${ARGOCD_OPERATOR_VERSION}                      "
║               ║ Core Version:     ${ARGOCD_CORE_VERSION}                          "
║               ║ Route:            https://${ARGOCD_URL}
║               ║ Username:         admin                                           ║
║               ║ Password:         argocd1234!                                     ║
║               ║ (or use 'Log in via OpenShift')                                   ║
EOF

if [ "$INSTALL_GITEA" = true ]; then
cat >> "${INFO_DIR}/environment_config.md" <<EOF
╠═══════════════╬═══════════════════════════════════════════════════════════════════╣
║ Gitea         ║                                                                   ║
║               ║ App Version:   ${GITEA_APP_VERSION}                               "
║               ║ Chart Version: ${GITEA_HELM_CHART_VERSION}                        "
║               ║ Chart Repo:    ${GITEA_CHART_REPO}                                "
║               ║ Route:         https://${GITEA_URL}
║               ║ Username:      admin                                              ║
║               ║ Password:      gitea1234!                                         ║
EOF
fi

if [ "$USE_GITHUB" = true ]; then
cat >> "${INFO_DIR}/environment_config.md" <<EOF
╠═══════════════╬═══════════════════════════════════════════════════════════════════╣
║ GitHub        ║                                                                   ║
║               ║ Organization: ${GITHUB_ORG}
EOF
if [ -n "$GITHUB_REPO" ]; then
cat >> "${INFO_DIR}/environment_config.md" <<EOF
║               ║ Repository:   ${GITHUB_REPO}
EOF
else
cat >> "${INFO_DIR}/environment_config.md" <<EOF
║               ║ Access: All repositories in organization                          ║
EOF
fi
fi

cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
╚═══════════════╩═══════════════════════════════════════════════════════════════════╝
```

## Quick Access Commands

### ArgoCD
\`\`\`bash
# Get ArgoCD URL
echo "https://\$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"

# Login with ArgoCD CLI (Option 1 - Recommended: Interactive)
argocd login \$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}') \\
  --username admin --insecure
# When prompted, enter password: argocd1234!

# Login with ArgoCD CLI (Option 2 - Single Command)
# Note: Password must be properly quoted due to special character
argocd login \$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}') \\
  --username admin --password 'argocd1234!' --insecure
\`\`\`

EOF

if [ "$INSTALL_GITEA" = true ]; then
cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
### Gitea
```bash
# Get Gitea URL
echo "https://$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')"
```

EOF
fi

cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
## Default Credentials

### ArgoCD
- **Username**: `admin`
- **Password**: `argocd1234!`
- **Alternative**: Use "Log in via OpenShift" with your OpenShift credentials

EOF

if [ "$INSTALL_GITEA" = true ]; then
cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
### Gitea
- **Username**: `admin`
- **Password**: `gitea1234!`

EOF
fi

cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
## Verification Commands

### Check ArgoCD Status
```bash
oc get pods -n openshift-gitops
oc get argocd -n openshift-gitops
oc get route openshift-gitops-server -n openshift-gitops
```

EOF

if [ "$INSTALL_GITEA" = true ]; then
cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
### Check Gitea Status
```bash
oc get pods -n gitea
helm list -n gitea
oc get route gitea -n gitea
```

EOF
fi

cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
## Security Notes

⚠️ **Important**: These are default credentials for development/testing purposes.

For production environments:
1. Change the default passwords immediately after installation
2. Use OpenShift OAuth for ArgoCD authentication
3. Configure RBAC policies appropriately
4. Use secrets management solutions (e.g., External Secrets Operator)
5. Enable audit logging

## Changing Passwords

### ArgoCD Admin Password

1. Generate a new bcrypt hash:
   ```bash
   htpasswd -nbBC 10 "" your-new-password | tr -d ':\n' | sed 's/$2y/$2a/'
   ```

2. Update the secret:
   ```bash
   oc patch secret argocd-secret -n openshift-gitops \
     -p '{"stringData": {"admin.password": "<your-bcrypt-hash>"}}'
   ```

3. Restart ArgoCD server:
   ```bash
   oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops
   ```

EOF

if [ "$INSTALL_GITEA" = true ]; then
cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
### Gitea Admin Password

1. Log into Gitea UI
2. Go to Settings → Account → Password
3. Update your password

Or use Gitea CLI:
```bash
oc exec -n gitea deployment/gitea -- gitea admin user change-password \
  --username admin --password your-new-password
```

EOF
fi

cat >> "${INFO_DIR}/environment_config.md" <<'EOF'
## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/)
- [Gitea Documentation](https://docs.gitea.io/)
- [Setup Guide](../assets/0_initial_setup/README.md)
- [Quick Reference](../assets/0_initial_setup/QUICK_REFERENCE.md)

---

**Installation Script**: `assets/0_initial_setup/install.sh`
EOF

print_success "Environment configuration saved to: ${INFO_DIR}/environment_config.md"
print_success "Component versions saved to: ${INFO_DIR}/versions.csv"
