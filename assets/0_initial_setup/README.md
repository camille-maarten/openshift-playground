# Red Hat OpenShift GitOps (ArgoCD) Setup

This directory contains all the necessary configurations to deploy and configure Red Hat OpenShift GitOps (ArgoCD) on an OpenShift cluster.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Installation Steps](#installation-steps)
- [Post-Installation Configuration](#post-installation-configuration)
- [Accessing ArgoCD UI](#accessing-argocd-ui)
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

The easiest way to install is using the provided script:

```bash
./install.sh
```

The script will:
1. Check for required secret files
2. Verify you're logged into OpenShift
3. Install the operator and ArgoCD
4. Display access information

**Note**: Before running the script, you must create the required secret files (see [Prepare Secret Files](#prepare-secret-files) below).

### Prepare Secret Files

Before installation, you need to create secret files from the templates:

```bash
# Copy the Git credentials template
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml

# Copy the webhook secrets template
cp manifests/09-webhook-secret.yaml.template manifests/09-webhook-secret.yaml

# Edit both files and add your actual credentials
vim manifests/08-git-credentials-secret.yaml
vim manifests/09-webhook-secret.yaml
```

**Alternative**: If you want to skip secrets for now and configure them later:

```bash
# Create empty placeholder files
touch manifests/08-git-credentials-secret.yaml
touch manifests/09-webhook-secret.yaml
```

You can configure the actual secrets later via ArgoCD UI or CLI.

### Manual Installation Steps

If you prefer to install manually, follow these steps:

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

## Configuration Files

All numbered configuration files are located in the `manifests/` subdirectory.

### Core Installation Files

| File | Description |
|------|-------------|
| `manifests/01-namespace.yaml` | Creates the `openshift-gitops` namespace with monitoring enabled |
| `manifests/02-operatorgroup.yaml` | OperatorGroup for the GitOps operator |
| `manifests/03-subscription.yaml` | Subscription to install Red Hat GitOps operator from OperatorHub |
| `manifests/04-argocd-instance.yaml` | Main ArgoCD instance with HA, monitoring, and best practices configured |

### Configuration Files

| File | Description |
|------|-------------|
| `manifests/05-argocd-repositories-configmap.yaml` | ConfigMap for Git repository definitions |
| `manifests/06-argocd-cm-configmap.yaml` | General ArgoCD configuration (timeouts, Helm, Kustomize options, etc.) |
| `manifests/07-argocd-rbac-configmap.yaml` | RBAC policies and role mappings |

### Secrets

| File | Description |
|------|-------------|
| `manifests/08-git-credentials-secret.yaml.template` | Template for Git repository credentials (HTTPS/SSH) |
| `manifests/09-webhook-secret.yaml.template` | Template for webhook secrets and notification integrations |
| `manifests/10-admin-password-secret.yaml` | ArgoCD admin password secret (default: `argo1234!`) |

**Important**: Files `08` and `09` are templates. You must create actual secret files before running the installation script:
```bash
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
cp manifests/09-webhook-secret.yaml.template manifests/09-webhook-secret.yaml
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

## Quick Installation Script

The repository includes an automated installation script `install.sh` that handles all steps:

```bash
# First, prepare your secret files
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
cp manifests/09-webhook-secret.yaml.template manifests/09-webhook-secret.yaml
# Edit the files with your credentials or leave them empty for now

# Run the installation
./install.sh
```

The script will automatically:
1. Check for required secret files
2. Create the namespace
3. Install the Red Hat GitOps operator
4. Apply the admin password secret
5. Deploy the ArgoCD instance
6. Apply all ConfigMaps and secrets
7. Display access information

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
