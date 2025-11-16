# Red Hat OpenShift GitOps (ArgoCD) and GitLab Setup

This directory contains all the necessary configurations to deploy and configure:
1. **Red Hat OpenShift GitOps (ArgoCD)** - GitOps continuous delivery tool
2. **GitLab Community Edition** - Source code management and CI/CD platform

These tools work together to provide a complete GitOps workflow on OpenShift.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Installation Steps](#installation-steps)
  - [Quick Installation](#quick-installation-recommended)
  - [ArgoCD Manual Installation](#argocd-manual-installation)
  - [GitLab Manual Installation](#gitlab-manual-installation)
- [Post-Installation Configuration](#post-installation-configuration)
- [Accessing ArgoCD UI](#accessing-argocd-ui)
- [Accessing GitLab UI](#accessing-gitlab-ui)
- [Configuration Files](#configuration-files)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)

## Prerequisites

- Access to an OpenShift cluster (4.10 or later recommended)
- OpenShift CLI (`oc`) installed on your local machine
- Cluster admin permissions

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

## Installation Steps

### Quick Installation (Recommended)

#### Before You Begin - Complete These Steps First!

**STEP 1: Prepare GitLab User Configuration**

You need to create ONE configuration file before running the installation. Follow these detailed steps:

```bash
# Navigate to the 0_initial_setup directory (if not already there)
cd assets/0_initial_setup

# Copy the template file
cp manifests/15-gitlab-user-password-secret.yaml.template manifests/15-gitlab-user-password-secret.yaml
```

**STEP 2: Add Your SSH Key (OPTIONAL but Recommended)**

SSH keys allow you to clone and push to GitLab without entering your password each time.

**Option A: Use an existing SSH key**

```bash
# Check if you already have an SSH key
ls ~/.ssh/id_*.pub

# If you see files like id_ed25519.pub or id_rsa.pub, you have a key!
# Display your public key
cat ~/.ssh/id_ed25519.pub
# OR
cat ~/.ssh/id_rsa.pub

# Copy the ENTIRE output (it's one long line starting with ssh-ed25519 or ssh-rsa)
```

**Option B: Create a new SSH key** (if you don't have one)

```bash
# Generate a new SSH key (just press ENTER for all prompts to use defaults)
ssh-keygen -t ed25519 -C "your-email@example.com"

# Display your new public key
cat ~/.ssh/id_ed25519.pub

# Copy the ENTIRE output
```

**Option C: Skip SSH** (you can use HTTPS instead with username/password)

If you skip this step, you'll use HTTPS with `root / gitlab1234!` to clone repositories. You can add an SSH key later through the GitLab UI.

**STEP 3: Edit the Configuration File**

```bash
# Open the file with your favorite editor:
vim manifests/15-gitlab-user-password-secret.yaml
# OR
nano manifests/15-gitlab-user-password-secret.yaml
# OR
code manifests/15-gitlab-user-password-secret.yaml
```

Find this line in the file:
```yaml
  # ssh_public_key: PASTE_YOUR_SSH_PUBLIC_KEY_HERE
```

If you have an SSH key:
1. Remove the `#` at the beginning
2. Replace `PASTE_YOUR_SSH_PUBLIC_KEY_HERE` with your actual public key

Example - BEFORE:
```yaml
  # ssh_public_key: PASTE_YOUR_SSH_PUBLIC_KEY_HERE
```

Example - AFTER:
```yaml
  ssh_public_key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJl3dIeudNqd0DPMH/w5bQPy3rMh0p1RoJp1S9F5dN7N your-email@example.com
```

**Save and exit:**
- In vim: Press `ESC`, then type `:wq` and press `ENTER`
- In nano: Press `CTRL+X`, then `Y`, then `ENTER`
- In VS Code: Press `CTRL+S` (or `CMD+S` on Mac), then close the file

#### Run the Installation

Now you're ready! Run the installation script:

```bash
# Make the script executable (first time only)
chmod +x install.sh

# Run the installation
./install.sh
```

The script will:
1. Validate that you've created the configuration file
2. Verify you're logged into OpenShift
3. Install Red Hat GitOps operator and ArgoCD
4. Install GitLab operator and GitLab CE
5. **Automatically configure ArgoCD to use the local GitLab instance**
6. Display access information for both systems

**Installation time**: Approximately 10-15 minutes total

**Note**: If you want to use GitHub or another external Git service instead of (or in addition to) GitLab, see [Appendix: Using External Git Providers](#appendix-using-external-git-providers).

### ArgoCD Manual Installation

If you prefer to install ArgoCD manually, follow these steps:

#### Step 1: Create Namespace

Create the `openshift-gitops` namespace:

```bash
oc apply -f manifests/01-namespace.yaml
```

Verify the namespace was created:

```bash
oc get namespace openshift-gitops
```

#### Step 2: Create OperatorGroup

Create the OperatorGroup for the GitOps operator:

```bash
oc apply -f manifests/02-operatorgroup.yaml
```

Verify:

```bash
oc get operatorgroup -n openshift-gitops
```

#### Step 3: Install Red Hat GitOps Operator

Install the operator via subscription:

```bash
oc apply -f manifests/03-subscription.yaml
```

Wait for the operator to be installed (this may take 2-5 minutes):

```bash
# Watch the subscription status
oc get subscription openshift-gitops-operator -n openshift-gitops -w

# Check ClusterServiceVersion (CSV)
oc get csv -n openshift-gitops

# Verify operator pods are running
oc get pods -n openshift-gitops
```

The operator should show `Succeeded` state.

#### Step 4: Apply Admin Password Secret

Apply the admin password secret (default password: `argo1234!`):

```bash
oc apply -f manifests/10-admin-password-secret.yaml
```

To change the admin password, edit the `manifests/10-admin-password-secret.yaml` file before applying.

#### Step 5: Deploy ArgoCD Instance

Once the operator is running, deploy the ArgoCD instance:

```bash
oc apply -f manifests/04-argocd-instance.yaml
```

Wait for all ArgoCD components to be ready (this may take 3-5 minutes):

```bash
# Watch ArgoCD instance
oc get argocd -n openshift-gitops -w

# Check all pods are running
oc get pods -n openshift-gitops

# Expected pods:
# - openshift-gitops-application-controller
# - openshift-gitops-applicationset-controller
# - openshift-gitops-dex-server
# - openshift-gitops-redis
# - openshift-gitops-repo-server
# - openshift-gitops-server
```

#### Step 6: Apply Configuration and Secrets

Apply ConfigMaps and secret files:

```bash
# Repository configuration
oc apply -f manifests/05-argocd-repositories-configmap.yaml

# General ArgoCD configuration
oc apply -f manifests/06-argocd-cm-configmap.yaml

# RBAC configuration
oc apply -f manifests/07-argocd-rbac-configmap.yaml

# Git credentials
oc apply -f manifests/08-git-credentials-secret.yaml

# Webhook secrets
oc apply -f manifests/09-webhook-secret.yaml
```

**Note**: If you apply these ConfigMaps after the ArgoCD instance is created, you may need to restart the ArgoCD server pod for changes to take effect:

```bash
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops
```

### GitLab Manual Installation

If you prefer to install GitLab manually, follow these steps:

#### Step 1: Create GitLab Namespace

```bash
oc apply -f manifests/11-gitlab-namespace.yaml
```

Verify:

```bash
oc get namespace gitlab-system
```

#### Step 2: Create GitLab OperatorGroup

```bash
oc apply -f manifests/12-gitlab-operatorgroup.yaml
```

Verify:

```bash
oc get operatorgroup -n gitlab-system
```

#### Step 3: Install GitLab Operator

```bash
oc apply -f manifests/13-gitlab-subscription.yaml
```

Wait for the operator to be installed (2-5 minutes):

```bash
# Watch the subscription status
oc get subscription gitlab-operator-kubernetes -n gitlab-system -w

# Check ClusterServiceVersion (CSV)
oc get csv -n gitlab-system

# Verify operator pods are running
oc get pods -n gitlab-system
```

#### Step 4: Apply GitLab Secrets

Apply the root password and Minio secrets:

```bash
# Root password secret (default: gitlab1234!)
oc apply -f manifests/14-gitlab-root-password-secret.yaml

# User password secret
oc apply -f manifests/15-gitlab-user-password-secret.yaml

# Minio credentials secret
oc apply -f manifests/19-gitlab-minio-secret.yaml
```

#### Step 5: Apply GitLab ConfigMap

```bash
oc apply -f manifests/17-gitlab-configmap.yaml
```

#### Step 6: Deploy GitLab Instance

This step will take 5-10 minutes as GitLab deploys multiple components:

```bash
oc apply -f manifests/16-gitlab-instance.yaml
```

Monitor the deployment:

```bash
# Watch GitLab pods
oc get pods -n gitlab-system -w

# Check GitLab instance status
oc get gitlab -n gitlab-system

# Expected pods (may take 5-10 minutes):
# - gitlab-gitaly-*
# - gitlab-gitlab-shell-*
# - gitlab-migrations-*
# - gitlab-postgresql-*
# - gitlab-redis-master-*
# - gitlab-registry-*
# - gitlab-sidekiq-*
# - gitlab-webservice-*
# - gitlab-nginx-ingress-controller-* (if enabled)
# - gitlab-runner-*
```

#### Step 7: Create Routes (Optional)

Create OpenShift routes for GitLab:

```bash
oc apply -f manifests/18-gitlab-route.yaml
```

Get the GitLab URL:

```bash
oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}'
```

## Post-Installation Configuration

### Grant Additional Users Access

To grant access to other users or groups:

1. Edit the RBAC ConfigMap (`manifests/07-argocd-rbac-configmap.yaml`)
2. Add group mappings in the `policy.csv` section:
   ```csv
   g, your-openshift-group, role:developer
   ```
3. Apply the changes:
   ```bash
   oc apply -f manifests/07-argocd-rbac-configmap.yaml
   ```

### Add Git Repositories

To add Git repositories to ArgoCD:

**Option 1: Via ConfigMap** (for public repos)
1. Edit `manifests/05-argocd-repositories-configmap.yaml`
2. Add your repository under the `repositories` section
3. Apply: `oc apply -f manifests/05-argocd-repositories-configmap.yaml`

**Option 2: Via Secret** (for private repos)
1. Create a secret using the template in `manifests/08-git-credentials-secret.yaml.template`
2. Apply the secret

**Option 3: Via ArgoCD CLI**
```bash
argocd repo add https://github.com/your-org/your-repo \
  --username YOUR_USERNAME \
  --password YOUR_TOKEN
```

## Accessing ArgoCD UI

### Get the Route URL

```bash
# Get the ArgoCD server route
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```

### Get Admin Password

The admin password is set in the `manifests/10-admin-password-secret.yaml` file.

**Default password**: `argo1234!`

To change the password:
1. Edit `manifests/10-admin-password-secret.yaml`
2. Update the `admin.password` field with a new bcrypt hash
3. Reapply: `oc apply -f manifests/10-admin-password-secret.yaml`
4. Restart ArgoCD server: `oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops`

### Login Options

**Option 1: OpenShift OAuth** (Recommended)
1. Click "Log in via OpenShift" on the ArgoCD login page
2. Use your OpenShift credentials

**Option 2: Admin User**
- Username: `admin`
- Password: `argo1234!` (or your custom password if changed)

### Login via ArgoCD CLI

```bash
# Install ArgoCD CLI first (if not already installed)
# macOS:
brew install argocd

# Linux:
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')

argocd login $ARGOCD_ROUTE --username admin --password argo1234! --insecure
```

## Accessing GitLab UI

### Get the Route URL

```bash
# Get the GitLab route
oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}'
```

### Get Root Password

The root password is set in the `manifests/14-gitlab-root-password-secret.yaml` file.

**Default password**: `gitlab1234!`

To change the password:
1. Edit `manifests/14-gitlab-root-password-secret.yaml`
2. Update the `password` field
3. Reapply: `oc apply -f manifests/14-gitlab-root-password-secret.yaml`
4. Restart GitLab webservice: `oc delete pod -l app=webservice -n gitlab-system`

### Login to GitLab

1. Get the GitLab URL:
   ```bash
   echo "https://$(oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}')"
   ```

2. Open the URL in your browser

3. Login with:
   - **Username**: `root`
   - **Password**: `gitlab1234!` (or your custom password if changed)

### First-time Setup

After logging in for the first time:

1. **Change root password** (recommended):
   - Go to User Settings → Password
   - Update to a secure password

2. **Create a new user** (optional):
   - Go to Admin Area → Users
   - Click "New user"
   - Fill in user details
   - Set password using the user password secret

3. **Create your first project**:
   - Click "New project"
   - Choose "Create blank project"
   - Enter project name and details
   - Click "Create project"

### GitLab CLI (glab)

```bash
# Install glab CLI (optional)
# macOS:
brew install glab

# Linux:
# Download from https://gitlab.com/gitlab-org/cli/-/releases

# Configure glab
GITLAB_URL=$(oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}')
glab auth login --hostname $GITLAB_URL

# Follow the prompts to authenticate
```

### Create a Personal Access Token

To use GitLab API or integrate with ArgoCD:

1. Go to User Settings → Access Tokens
2. Enter token name (e.g., "ArgoCD Integration")
3. Select scopes:
   - `api` - Full API access
   - `read_repository` - Read repository
   - `write_repository` - Write repository
4. Click "Create personal access token"
5. Copy the token (you won't be able to see it again)

This token can be used in ArgoCD to connect to GitLab repositories.

## Configuration Files

All numbered configuration files are located in the `manifests/` subdirectory.

### ArgoCD Installation Files

| File | Description |
|------|-------------|
| `manifests/01-namespace.yaml` | Creates the `openshift-gitops` namespace with monitoring enabled |
| `manifests/02-operatorgroup.yaml` | OperatorGroup for the GitOps operator |
| `manifests/03-subscription.yaml` | Subscription to install Red Hat GitOps operator from OperatorHub |
| `manifests/04-argocd-instance.yaml` | Main ArgoCD instance with HA, monitoring, and best practices configured |
| `manifests/05-argocd-repositories-configmap.yaml` | ConfigMap for Git repository definitions |
| `manifests/06-argocd-cm-configmap.yaml` | General ArgoCD configuration (timeouts, Helm, Kustomize options, etc.) |
| `manifests/07-argocd-rbac-configmap.yaml` | RBAC policies and role mappings |
| `manifests/08-git-credentials-secret.yaml.template` | Template for Git repository credentials (HTTPS/SSH) |
| `manifests/09-webhook-secret.yaml.template` | Template for webhook secrets and notification integrations |
| `manifests/10-admin-password-secret.yaml` | ArgoCD admin password secret (default: `argo1234!`) |

### GitLab Installation Files

| File | Description |
|------|-------------|
| `manifests/11-gitlab-namespace.yaml` | Creates the `gitlab-system` namespace with monitoring enabled |
| `manifests/12-gitlab-operatorgroup.yaml` | OperatorGroup for the GitLab operator |
| `manifests/13-gitlab-subscription.yaml` | Subscription to install GitLab operator from Community Operators |
| `manifests/14-gitlab-root-password-secret.yaml` | GitLab root (admin) password secret (default: `gitlab1234!`) |
| `manifests/15-gitlab-user-password-secret.yaml.template` | Template for GitLab user password and SSH keys |
| `manifests/16-gitlab-instance.yaml` | GitLab CE instance configuration with PostgreSQL, Redis, Registry, etc. |
| `manifests/17-gitlab-configmap.yaml` | GitLab configuration options and feature flags |
| `manifests/18-gitlab-route.yaml` | OpenShift routes for GitLab web UI and container registry |
| `manifests/19-gitlab-minio-secret.yaml` | Minio (object storage) credentials for GitLab |

**Important**: Files `08`, `09`, and `15` are templates. You must create actual secret files before running the installation script:
```bash
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
cp manifests/09-webhook-secret.yaml.template manifests/09-webhook-secret.yaml
cp manifests/15-gitlab-user-password-secret.yaml.template manifests/15-gitlab-user-password-secret.yaml
```

### Documentation & Scripts

| File | Description |
|------|-------------|
| `README.md` | This comprehensive guide |
| `QUICK_REFERENCE.md` | Quick command reference |
| `install.sh` | Automated installation script |
| `.gitignore` | Prevents committing actual secrets |

## Best Practices

### Security

1. **Use OpenShift OAuth**: The configuration uses OpenShift OAuth for authentication
2. **Separate Secrets**: Never commit actual secrets to Git - use templates
3. **RBAC**: Follow principle of least privilege - default policy is read-only
4. **TLS**: Routes are configured with TLS re-encryption

### High Availability

- HA is enabled in the ArgoCD instance configuration
- Application controller is configured for high performance
- Resource limits and requests are set appropriately

### Resource Management

- All components have resource requests and limits defined
- Autoscaling is enabled for the ArgoCD server
- Monitoring is enabled for observability

### GitOps Workflow

1. Store all Kubernetes manifests in Git repositories
2. Use ArgoCD Applications to deploy from Git
3. Use ArgoCD Projects to organize and control access
4. Enable auto-sync for non-production environments
5. Use manual sync for production environments

## Troubleshooting

### Operator Installation Issues

```bash
# Check subscription status
oc get subscription openshift-gitops-operator -n openshift-gitops -o yaml

# Check install plan
oc get installplan -n openshift-gitops

# Check CSV status
oc get csv -n openshift-gitops

# Check operator logs
oc logs -n openshift-gitops -l control-plane=gitops-operator
```

### ArgoCD Instance Issues

```bash
# Check ArgoCD instance status
oc get argocd openshift-gitops -n openshift-gitops -o yaml

# Check all pods
oc get pods -n openshift-gitops

# Check specific component logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-repo-server
```

### Common Issues

**Issue: Pods not starting**
```bash
# Check events
oc get events -n openshift-gitops --sort-by='.lastTimestamp'

# Check pod description
oc describe pod <pod-name> -n openshift-gitops
```

**Issue: Can't access UI**
```bash
# Verify route exists
oc get route -n openshift-gitops

# Check route status
oc describe route openshift-gitops-server -n openshift-gitops
```

**Issue: Authentication problems**
```bash
# Verify Dex is running
oc get pods -n openshift-gitops | grep dex

# Check Dex logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-dex-server
```

### Restart ArgoCD Components

If you make configuration changes, you may need to restart components:

```bash
# Restart ArgoCD server
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops

# Restart application controller
oc delete pod -l app.kubernetes.io/name=openshift-gitops-application-controller -n openshift-gitops

# Restart repo server
oc delete pod -l app.kubernetes.io/name=openshift-gitops-repo-server -n openshift-gitops
```

## Verifying the Installation

Run this complete verification:

```bash
# 1. Check namespace
oc get namespace openshift-gitops

# 2. Check operator
oc get csv -n openshift-gitops

# 3. Check ArgoCD instance
oc get argocd -n openshift-gitops

# 4. Check all pods are running
oc get pods -n openshift-gitops

# 5. Check route
oc get route openshift-gitops-server -n openshift-gitops

# 6. Admin password
echo "Admin password: argo1234!"

# 7. Get ArgoCD URL
echo "ArgoCD URL: https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
```

## Automatic GitLab Integration

The installation script automatically configures ArgoCD to use the local GitLab instance:

- **No manual configuration required** for GitLab repositories
- ArgoCD is pre-configured with GitLab root credentials
- All GitLab projects are automatically accessible to ArgoCD
- Uses internal cluster DNS for communication (no external routes needed)

After installation, simply:
1. Create a project in GitLab
2. Add your Kubernetes manifests to the repository
3. Create an ArgoCD Application pointing to the GitLab repository URL

## Additional Resources

- [Red Hat OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Best Practices](https://www.weave.works/blog/gitops-operations-by-pull-request)
- [OpenShift CLI Documentation](https://docs.openshift.com/container-platform/latest/cli_reference/openshift_cli/getting-started-cli.html)

## Next Steps

After installing ArgoCD:

1. Create an ArgoCD Application to deploy your first application
2. Set up a Git repository with your Kubernetes manifests
3. Configure ArgoCD Projects for multi-tenancy
4. Set up notifications for deployment events
5. Explore ApplicationSets for managing multiple applications

Example ArgoCD Application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## Appendix: Using External Git Providers

By default, this installation configures ArgoCD to use the local GitLab instance. If you prefer to use **GitHub**, **Bitbucket**, or another external Git service, follow these instructions.

### Option 1: Using GitHub or External Git with HTTPS

#### Step 1: Create Git Credentials Secret

Copy and edit the template:

```bash
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
vim manifests/08-git-credentials-secret.yaml
```

Edit the secret to include your GitHub credentials:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: github-credentials
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  # GitHub repository URL
  url: https://github.com/your-org/your-repo

  # GitHub username
  username: YOUR_GITHUB_USERNAME

  # Personal Access Token (create at: https://github.com/settings/tokens)
  password: YOUR_GITHUB_PERSONAL_ACCESS_TOKEN
```

Apply the secret:

```bash
oc apply -f manifests/08-git-credentials-secret.yaml
```

#### Step 2: Create Webhook Secret (Optional)

For webhook integration with GitHub:

```bash
cp manifests/09-webhook-secret.yaml.template manifests/09-webhook-secret.yaml
vim manifests/09-webhook-secret.yaml
```

Edit to add your webhook secret:

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-webhook-secret
  namespace: openshift-gitops
type: Opaque
stringData:
  # Generate with: openssl rand -hex 20
  github.secret: YOUR_GITHUB_WEBHOOK_SECRET
```

Apply the secret:

```bash
oc apply -f manifests/09-webhook-secret.yaml
```

### Option 2: Using SSH Keys

For SSH-based authentication:

1. Generate an SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "argocd@openshift" -f ~/.ssh/argocd_ed25519
   ```

2. Add the public key to your Git provider:
   - **GitHub**: Settings → SSH and GPG keys → New SSH key
   - **GitLab**: User Settings → SSH Keys → Add new key
   - **Bitbucket**: Personal settings → SSH keys → Add key

3. Create the secret with your private key:
   ```bash
   cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
   ```

4. Edit the file:
   ```yaml
   ---
   apiVersion: v1
   kind: Secret
   metadata:
     name: github-ssh-credentials
     namespace: openshift-gitops
     labels:
       argocd.argoproj.io/secret-type: repository
   type: Opaque
   stringData:
     # SSH URL
     url: git@github.com:your-org/your-repo.git

     # SSH private key
     sshPrivateKey: |
       -----BEGIN OPENSSH PRIVATE KEY-----
       YOUR_PRIVATE_KEY_CONTENT_HERE
       -----END OPENSSH PRIVATE KEY-----
   ```

5. Apply the secret:
   ```bash
   oc apply -f manifests/08-git-credentials-secret.yaml
   ```

### Option 3: Using ArgoCD CLI

You can also add repositories via the ArgoCD CLI:

```bash
# Get ArgoCD route
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')

# Login to ArgoCD
argocd login $ARGOCD_ROUTE --username admin --password argo1234! --insecure

# Add repository with HTTPS
argocd repo add https://github.com/your-org/your-repo \
  --username YOUR_USERNAME \
  --password YOUR_PERSONAL_ACCESS_TOKEN

# Add repository with SSH
argocd repo add git@github.com:your-org/your-repo.git \
  --ssh-private-key-path ~/.ssh/argocd_ed25519

# List repositories
argocd repo list
```

### Option 4: Using ArgoCD UI

1. Access the ArgoCD UI
2. Go to Settings → Repositories
3. Click "Connect Repo"
4. Choose connection method:
   - **Via HTTPS**: Enter repository URL, username, and password/token
   - **Via SSH**: Enter repository URL and paste SSH private key
5. Click "Connect"

### GitHub Personal Access Token Permissions

When creating a GitHub Personal Access Token for ArgoCD, grant these permissions:

- **repo** - Full control of private repositories
  - repo:status
  - repo_deployment
  - public_repo
  - repo:invite

### Switching from GitLab to GitHub

If you installed with GitLab but want to switch to GitHub:

1. The local GitLab instance will remain functional
2. Add GitHub credentials using one of the methods above
3. ArgoCD will now have access to both GitLab and GitHub repositories
4. When creating ArgoCD Applications, specify the repository URL for either service

### Removing GitLab Integration

To remove the automatic GitLab integration:

```bash
# Remove the GitLab credentials secret
oc delete secret gitlab-repo-credentials -n openshift-gitops

# ArgoCD will no longer have automatic access to GitLab
# Add your external Git credentials using the methods above
```

### Multiple Git Providers

ArgoCD supports multiple Git providers simultaneously. You can configure:
- Local GitLab (automatic)
- GitHub (via secrets or CLI)
- Bitbucket (via secrets or CLI)
- GitLab.com (via secrets or CLI)
- Any other Git service

Each repository connection is independent, allowing you to use multiple services in parallel.
