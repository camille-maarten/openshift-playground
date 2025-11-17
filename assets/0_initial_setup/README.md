# Red Hat OpenShift GitOps (ArgoCD) with Gitea/GitHub Setup

This directory contains all the necessary configurations to deploy and configure:
1. **Red Hat OpenShift GitOps (ArgoCD)** - GitOps continuous delivery tool
2. **Gitea** (optional) - Lightweight self-hosted Git server
3. **GitHub Integration** (optional) - Connect to external GitHub organizations

These tools work together to provide a complete GitOps workflow on OpenShift.

> **📍 Important Note**: Unless otherwise specified, all commands in this guide should be run from the **repository root** directory. The installation script (`install.sh`) can be executed from **anywhere** - it will automatically navigate to the correct directory.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Installation Options](#installation-options)
- [Installation Steps](#installation-steps)
  - [Quick Installation](#quick-installation-recommended)
  - [Manual Installation](#manual-installation)
- [Post-Installation Configuration](#post-installation-configuration)
- [Accessing ArgoCD UI](#accessing-argocd-ui)
- [Accessing Gitea UI](#accessing-gitea-ui-if-installed)
- [GitHub Integration](#github-integration)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Prerequisites

- Access to an OpenShift cluster (4.10 or later recommended)
- OpenShift CLI (`oc`) installed on your local machine
- Helm 3.x installed on your local machine
- Cluster admin permissions

### Installing Prerequisites

**OpenShift CLI (`oc`)**:
- Download from: https://mirror.openshift.com/pub/openshift-v4/clients/ocp/

**Helm 3.x**:
```bash
# macOS
brew install helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

## Getting Started

### 1. Get the OpenShift Login Command

1. Open your OpenShift Web Console in a browser
2. Click on your username in the top-right corner
3. Select **"Copy login command"** from the dropdown menu
4. You'll be redirected to a new page - click **"Display Token"**
5. Copy the `oc login` command that looks like:
   ```bash
   oc login --token=sha256~xxxxxx --server=https://api.your-cluster.com:6443
   ```
6. Paste and run this command in your terminal

### 2. Verify Cluster Access

```bash
# Verify you're logged in
oc whoami

# Check your permissions
oc auth can-i create projects
```

## Installation Options

The installation script offers three Git server options:

### Option 1: Gitea (Local Git Server)
- **Best for**: Learning, development, air-gapped environments
- **Pros**: Fully self-contained, lightweight, no external dependencies
- **Cons**: Requires cluster resources, additional management

### Option 2: GitHub Organization
- **Best for**: Production, existing GitHub workflows, team collaboration
- **Pros**: No cluster resources needed, familiar interface, enterprise features
- **Cons**: Requires internet access, external dependency

### Option 3: ArgoCD Only
- **Best for**: Adding Git repositories manually later
- **Pros**: Maximum flexibility
- **Cons**: Requires manual configuration of Git repositories

## Installation Steps

### Quick Installation (Recommended)

The automated installation script will guide you through the setup:

```bash
# From repository root
bash assets/0_initial_setup/install.sh
```

The script will:
1. Check prerequisites (oc CLI, Helm)
2. Ask you to choose a Git server option
3. For **Gitea**: Automatically install and configure everything
4. For **GitHub**: Request your organization name and Personal Access Token
5. Install ArgoCD
6. Configure the selected Git integration
7. Display access information

#### GitHub Setup (if choosing Option 2)

Before running the script, prepare:

**Required Information:**
- **GitHub Organization or Username**: Your GitHub org name (e.g., `my-company`)
- **Repository Name** (optional): Specific repo name, or leave empty for org-wide access
- **Personal Access Token**: Create at https://github.com/settings/tokens

**Creating a GitHub Personal Access Token:**
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name like "ArgoCD OpenShift"
4. Select scopes:
   - `repo` (Full control of private repositories)
   - `read:org` (if using organization)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again!)

### Manual Installation

If you prefer to install components manually:

#### Step 1: Install ArgoCD

```bash
# From repository root
cd assets/0_initial_setup

# Create namespace and install operator
oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-operatorgroup.yaml
oc apply -f manifests/03-subscription.yaml

# Wait for operator to be ready
oc get csv -n openshift-gitops -w

# Configure ArgoCD
oc apply -f manifests/10-admin-password-secret.yaml
oc apply -f manifests/04-argocd-instance.yaml

# Apply ConfigMaps
oc apply -f manifests/05-argocd-repositories-configmap.yaml
# Note: 06-argocd-cm-configmap.yaml is managed by the ArgoCD operator via extraConfig
# The operator generates this ConfigMap from the ArgoCD CR settings
oc apply -f manifests/07-argocd-rbac-configmap.yaml

# Restart ArgoCD server to pick up changes
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops
```

#### Step 2: Install Gitea (Optional)

```bash
# Add Gitea Helm repository
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update

# Create namespace
oc create namespace gitea

# Get cluster domain
CLUSTER_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')

# Create values file
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
    database:
      DB_TYPE: sqlite3
    security:
      INSTALL_LOCK: true

service:
  http:
    type: ClusterIP
    port: 3000

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

# Install Gitea
helm upgrade --install gitea gitea-charts/gitea \
  --namespace gitea \
  --values /tmp/gitea-values.yaml \
  --wait \
  --timeout 600s

# Create OpenShift route
oc create route edge gitea \
  --service=gitea-http \
  --port=http \
  -n gitea
```

#### Step 3: Configure GitHub Integration (Optional)

```bash
# Set your GitHub details
GITHUB_ORG="your-org-or-username"
GITHUB_TOKEN="your-personal-access-token"

# Create ArgoCD repository secret
cat <<EOF | oc apply -f -
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
  url: https://github.com/${GITHUB_ORG}
  password: ${GITHUB_TOKEN}
  username: ${GITHUB_ORG}
EOF
```

## Post-Installation Configuration

### Get Access Information

```bash
# ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Gitea URL (if installed)
oc get route gitea -n gitea -o jsonpath='{.spec.host}'
```

### Default Credentials

**ArgoCD:**
- Username: `admin` or `admin-user`
- Password: `argocd1234!` (admin) or `argocd1234!` (admin-user)
- Alternatively: Use "Log in via OpenShift" with your OpenShift credentials

**Gitea (if installed):**
- Username: `admin`
- Password: `gitea1234!`

## Accessing ArgoCD UI

1. Get the ArgoCD URL:
   ```bash
   echo "https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
   ```

2. Open the URL in your browser

3. Login using one of these methods:
   - **OpenShift OAuth** (Recommended): Click "LOG IN VIA OPENSHIFT"
   - **Admin Account**: Username `admin`, Password `argocd1234!`
   - **Admin User Account**: Username `admin-user`, Password `argocd1234!`

## Accessing Gitea UI (if installed)

1. Get the Gitea URL:
   ```bash
   echo "https://$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')"
   ```

2. Open the URL in your browser

3. Login with:
   - Username: `admin`
   - Password: `gitea1234!`

4. Create your first repository:
   - Click the "+" icon in the top-right
   - Select "New Repository"
   - Fill in repository details
   - Click "Create Repository"

## GitHub Integration

If you configured GitHub integration, you can now create ArgoCD applications that use your GitHub repositories.

### Creating an ArgoCD Application with GitHub

1. In ArgoCD UI, click "NEW APP"
2. Fill in the form:
   - **Application Name**: `my-app`
   - **Project**: `default`
   - **Sync Policy**: Choose `Automatic` or `Manual`
   - **Repository URL**: `https://github.com/your-org/your-repo`
   - **Path**: Path to Kubernetes manifests in the repo (e.g., `k8s/`)
   - **Cluster URL**: `https://kubernetes.default.svc`
   - **Namespace**: Target namespace for deployment
3. Click "CREATE"

### Verifying GitHub Connection

```bash
# Check if repository secret is created
oc get secret -n openshift-gitops | grep github

# View repository credentials (base64 encoded)
oc get secret github-org-YOUR_ORG -n openshift-gitops -o yaml
```

## Troubleshooting

### ArgoCD Pods Not Starting

```bash
# Check pod status
oc get pods -n openshift-gitops

# Check specific pod logs
oc logs -n openshift-gitops <pod-name>

# Check operator status
oc get csv -n openshift-gitops
```

### Gitea Not Accessible

```bash
# Check Gitea pod status
oc get pods -n gitea

# Check Gitea logs
oc logs -n gitea -l app.kubernetes.io/name=gitea

# Check route
oc get route gitea -n gitea

# Check Helm release
helm list -n gitea
```

### GitHub Integration Not Working

```bash
# Verify secret exists
oc get secret -n openshift-gitops | grep github

# Check secret content
oc get secret github-org-YOUR_ORG -n openshift-gitops -o yaml

# Test GitHub connectivity from ArgoCD
oc exec -n openshift-gitops deployment/openshift-gitops-repo-server -- \
  curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
```

### ArgoCD Can't Access Repository

```bash
# Check ArgoCD repository server logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=argocd-repo-server

# Verify repository secret
oc get secret -n openshift-gitops -l argocd.argoproj.io/secret-type=repository
```

## Configuration Files

- `manifests/01-namespace.yaml` - Creates openshift-gitops namespace
- `manifests/02-operatorgroup.yaml` - OperatorGroup for GitOps operator
- `manifests/03-subscription.yaml` - GitOps operator subscription
- `manifests/04-argocd-instance.yaml` - ArgoCD instance configuration
- `manifests/05-argocd-repositories-configmap.yaml` - Repository connections
- `manifests/06-argocd-cm-configmap.yaml` - ArgoCD general configuration
- `manifests/07-argocd-rbac-configmap.yaml` - RBAC policies
- `manifests/10-admin-password-secret.yaml` - ArgoCD admin password

## Best Practices

1. **Change Default Passwords**: After installation, change default passwords for ArgoCD and Gitea
2. **Use OpenShift OAuth**: Configure ArgoCD to use OpenShift OAuth for authentication
3. **Enable RBAC**: Configure role-based access control in ArgoCD
4. **Backup**: Regularly backup Gitea data and ArgoCD configurations
5. **Monitor Resources**: Keep an eye on resource usage for Gitea and ArgoCD
6. **Use GitHub Organizations**: For team collaboration, use GitHub organization-wide credentials

## Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
- [Gitea Documentation](https://docs.gitea.io/)
- [GitHub Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

## Quick Reference

See [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for common commands and operations.

## Next Steps

After installation:

1. **With Gitea**:
   - Create your first repository in Gitea
   - Push your Kubernetes manifests to the repository
   - Create an ArgoCD application pointing to your Gitea repository

2. **With GitHub**:
   - Ensure your Kubernetes manifests are in a GitHub repository
   - Create an ArgoCD application pointing to your GitHub repository

3. **ArgoCD Only**:
   - Manually add Git repository credentials in ArgoCD UI
   - Create your first application

---

**Need Help?** Check the [Troubleshooting](#troubleshooting) section or consult the official documentation linked above.
