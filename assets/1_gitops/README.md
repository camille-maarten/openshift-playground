# GitOps Manifests

This directory contains all GitOps manifests for the OpenShift playground environment, designed to be managed by ArgoCD.

## Overview

The GitOps approach enables declarative, version-controlled infrastructure and application management. All manifests in this directory are designed to be deployed and managed by ArgoCD, ensuring consistency and auditability.

## Directory Structure

```
1_gitops/
├── developerhub/          # Red Hat Developer Hub installation
│   ├── manifests/         # RHDH operator and instance manifests
│   ├── argocd-application.yaml
│   └── README.md
├── kafka/                 # AMQ Streams (Kafka) operator installation
│   ├── manifests/         # Kafka operator manifests
│   └── README.md
├── namespaces/            # Namespace definitions and configurations
│   ├── manifests/         # Playground namespace and policies
│   └── README.md
├── setup-gitops-repo.sh   # Script to setup Gitea repository
└── README.md              # This file
```

## Components

### 1. Developer Hub
- **Location**: `developerhub/`
- **Purpose**: Internal developer portal (Backstage)
- **Includes**:
  - RHDH operator subscription
  - Backstage instance configuration
  - RBAC policies with 5 personas
  - Dynamic plugin caching
  - PostgreSQL database

### 2. Kafka (AMQ Streams)
- **Location**: `kafka/`
- **Purpose**: Event streaming platform
- **Includes**:
  - AMQ Streams operator subscription
  - Ready for Kafka cluster deployments

### 3. Namespaces
- **Location**: `namespaces/`
- **Purpose**: Namespace configurations with quotas and policies
- **Includes**:
  - Playground namespace
  - Resource quotas
  - Limit ranges
  - Network policies

## GitOps Repository Setup

### Prerequisites

Before running the setup script, ensure:
- Gitea is installed and running in the `gitea` namespace
- `oc` CLI is installed and you're logged into OpenShift
- `git`, `curl`, and `jq` are installed

### Quick Start

To create a Gitea repository and push all GitOps manifests:

```bash
cd assets/1_gitops
./setup-gitops-repo.sh
```

### What the Script Does

The `setup-gitops-repo.sh` script automatically:

1. **Checks Prerequisites**: Verifies required tools are installed
2. **Connects to Gitea**: Gets the Gitea route and tests connectivity
3. **Authenticates**: Uses admin credentials to access Gitea API
4. **Creates Repository**: Creates `playground-gitops` repository (if not exists)
5. **Initializes Git**: Sets up local git repository
6. **Adds Remote**: Configures Gitea as git remote
7. **Commits Changes**: Commits all GitOps manifests
8. **Pushes to Gitea**: Pushes content to the repository

### Script Output

Upon successful completion, you'll see:

```
========================================
Setup Complete
========================================

Repository Information:
  Name:        playground-gitops
  URL:         https://gitea-gitea.apps.example.com/admin/playground-gitops
  Clone URL:   https://gitea-gitea.apps.example.com/admin/playground-gitops.git

Credentials:
  Username:    admin
  Password:    gitea1234!

Next Steps:
  1. Access the repository in Gitea: https://gitea-gitea.apps.example.com/admin/playground-gitops
  2. Configure ArgoCD Applications to use this repository
  3. Update ArgoCD Application manifests with the correct repoURL
```

## Using with ArgoCD

### Step 1: Update ArgoCD Application Manifests

After running the setup script, update the `repoURL` in ArgoCD Application manifests:

**Developer Hub** (`developerhub/argocd-application.yaml`):
```yaml
source:
  repoURL: https://gitea-gitea.apps.example.com/admin/playground-gitops.git
  targetRevision: main
  path: developerhub/manifests
```

**Future Applications**: Follow the same pattern for Kafka and namespace applications.

### Step 2: Deploy ArgoCD Applications

```bash
# Apply Developer Hub application
oc apply -f developerhub/argocd-application.yaml

# Future applications will be added here
```

### Step 3: Monitor in ArgoCD

```bash
# Via CLI
argocd app get developer-hub
argocd app sync developer-hub

# Via UI
oc get route openshift-gitops-server -n openshift-gitops
```

## Configuration

### Gitea Settings

Default configuration in `setup-gitops-repo.sh`:

```bash
REPO_NAME="playground-gitops"
GITEA_NAMESPACE="gitea"
GITEA_ADMIN_USER="admin"
GITEA_ADMIN_PASSWORD="gitea1234!"
```

To customize, edit the script before running.

### Git Configuration

The script automatically configures:
- Git user name: "GitOps Admin"
- Git user email: "gitops@playground.local"
- Main branch: "main"
- Disables SSL verification for self-signed certificates

## Troubleshooting

### Script Fails: Missing Tools

```bash
[ERROR] Missing required tools: jq

# Install missing tools
# macOS
brew install jq

# RHEL/CentOS
sudo yum install jq

# Ubuntu/Debian
sudo apt-get install jq
```

### Script Fails: Cannot Connect to Gitea

```bash
[ERROR] Cannot connect to Gitea at https://gitea-gitea.apps.example.com

# Check Gitea is running
oc get pods -n gitea

# Check Gitea route
oc get route gitea -n gitea

# Test connectivity manually
curl -k https://$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')
```

### Script Fails: Authentication Failed

```bash
[ERROR] Authentication failed (HTTP 401)

# Verify credentials
oc get secret -n gitea | grep gitea

# Check if admin password was changed
# Update GITEA_ADMIN_PASSWORD in the script
```

### Repository Already Exists

The script handles this automatically:
```bash
[WARNING] Repository 'playground-gitops' already exists
[INFO] Skipping repository creation (already exists)
```

It will push updates to the existing repository.

### Git Push Fails

```bash
# Check git remote
git remote -v

# Test connectivity
git ls-remote gitea

# Force push if needed (use with caution)
git push -u gitea main --force
```

## Manual Setup (Alternative)

If you prefer to set up manually:

### 1. Create Gitea Repository

```bash
# Get Gitea URL
GITEA_URL=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')

# Create repository via API
curl -k -X POST "https://${GITEA_URL}/api/v1/user/repos" \
  -u "admin:gitea1234!" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "playground-gitops",
    "description": "GitOps manifests for OpenShift playground",
    "private": false
  }'
```

### 2. Initialize and Push

```bash
cd assets/1_gitops

# Initialize git
git init
git checkout -b main

# Add files
git add .
git commit -m "Initial commit: GitOps manifests"

# Add remote and push
git remote add gitea "https://admin:gitea1234!@${GITEA_URL}/admin/playground-gitops.git"
git config http.sslVerify false
git push -u gitea main
```

## Best Practices

1. **Version Control**: Always commit changes before pushing
2. **Branching**: Use feature branches for testing changes
3. **Pull Requests**: Use Gitea's PR feature for review process
4. **Secrets**: Never commit sensitive data (use Sealed Secrets)
5. **Documentation**: Update READMEs when adding new components

## Security Considerations

### Credentials in Git Remote

The script stores credentials in the git remote URL for convenience. For production:

1. **Use SSH Keys**: Configure SSH authentication instead
2. **Use Tokens**: Create access tokens instead of passwords
3. **Remove Credentials**: After initial setup, update remote URL:

```bash
git remote set-url gitea https://gitea-route/admin/playground-gitops.git
# Then authenticate via SSH or token
```

### SSL Verification

The script disables SSL verification (`git config http.sslVerify false`) for self-signed certificates. For production:

1. Use proper SSL certificates
2. Add CA certificate to system trust store
3. Enable SSL verification

## Adding New Components

To add a new component to GitOps:

1. **Create Directory Structure**:
   ```bash
   mkdir -p 1_gitops/mycomponent/manifests
   ```

2. **Add Manifests**: Place Kubernetes/OpenShift YAMLs in `manifests/`

3. **Create ArgoCD Application**: Add `argocd-application.yaml`

4. **Document**: Create comprehensive `README.md`

5. **Run Setup Script**: Push changes to Gitea
   ```bash
   cd assets/1_gitops
   ./setup-gitops-repo.sh
   ```

6. **Deploy**: Apply ArgoCD Application manifest

## Maintenance

### Updating Manifests

```bash
# Make changes to manifests
vim developerhub/manifests/08-backstage-instance.yaml

# Commit and push
cd assets/1_gitops
git add .
git commit -m "Update Developer Hub configuration"
git push gitea main

# ArgoCD will auto-sync if enabled
# Or manually sync:
argocd app sync developer-hub
```

### Repository Cleanup

```bash
# Remove repository from Gitea
GITEA_URL=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')
curl -k -X DELETE "https://${GITEA_URL}/api/v1/repos/admin/playground-gitops" \
  -u "admin:gitea1234!"

# Clean local git
cd assets/1_gitops
rm -rf .git
```

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Gitea API Documentation](https://docs.gitea.io/en-us/api-usage/)
- [GitOps Principles](https://opengitops.dev/)
- [OpenShift GitOps](https://docs.openshift.com/container-platform/latest/cicd/gitops/understanding-openshift-gitops.html)
