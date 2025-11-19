# GitOps Manifests

This directory contains all GitOps manifests for the OpenShift playground environment, designed to be managed by ArgoCD.

## Overview

The GitOps approach enables declarative, version-controlled infrastructure and application management. All manifests in this directory are designed to be deployed and managed by ArgoCD, ensuring consistency and auditability.

---

## ⚠️ IMPORTANT: Git Remote Configuration

**WARNING**: The GitOps setup scripts create a **separate git repository** in this directory for Gitea integration.

### Two Git Repositories

When you run `setup-gitops-repo.sh`, it creates a **local git repository** at `assets/1_gitops/.git`:

- **Purpose**: Push manifests to in-cluster Gitea for ArgoCD to sync
- **Remote**: `gitea` pointing to the cluster's Gitea instance
- **Scope**: Only this directory (`assets/1_gitops/`)
- **Lifecycle**: Recreated for each cluster deployment

This is **separate** from the main GitHub repository at the project root (`openshift-playground/.git`).

### Before Committing to GitHub

**CRITICAL**: If you want to commit changes to GitHub (not Gitea), you MUST run cleanup scripts first.

#### Option 1: Complete Cleanup (Recommended)

Run the **all-in-one cleanup script**:

```bash
./assets/1_gitops/cleanup-for-github.sh
```

This script automatically:
- ✓ Restores `GITEA_URL` placeholders in ArgoCD Application manifests
- ✓ Removes Gitea remote from main repository
- ✓ Ensures `origin` points to GitHub
- ✓ Provides clear next steps

#### Option 2: Manual Step-by-Step

If you prefer to run steps individually:

1. **Restore URL placeholders** (undoes `setup-gitops-repo.sh` URL replacements):
   ```bash
   ./assets/1_gitops/restore-urls.sh
   ```

2. **Restore GitHub remote**:
   ```bash
   ./assets/1_gitops/restore-github-remote.sh
   ```

3. **Verify and commit**:
   ```bash
   cd /path/to/openshift-playground  # Navigate to repository root
   git branch                         # Verify current branch
   git status                         # Confirm you're in main repo
   git remote -v                      # Verify origin points to GitHub
   git add .
   git commit -m "Your commit message"
   git push origin <your-branch>
   ```

### Why This Matters

- **setup-gitops-repo.sh** creates `assets/1_gitops/.git` and configures the `gitea` remote
- This is **NOT** the main repository - it's a separate git repo just for Gitea uploads
- If you try to push from the wrong repository, your changes won't go to GitHub
- The `restore-github-remote.sh` script navigates to the **parent repository** and ensures `origin` points to GitHub

### Quick Reference

| Action | Repository/Scope | Command |
|--------|-----------------|---------|
| **Deploy to Cluster** | | |
| Upload manifests to Gitea | GitOps directory | `./assets/1_gitops/setup-gitops-repo.sh` |
| Deploy to ArgoCD | GitOps directory | `./assets/1_gitops/deploy-to-argocd.sh` |
| Complete upload + deploy | GitOps directory | `./assets/1_gitops/upload-and-deploy.sh` |
| **Prepare for GitHub** | | |
| Complete cleanup (recommended) | Main repository | `./assets/1_gitops/cleanup-for-github.sh` |
| Restore URL placeholders only | GitOps directory | `./assets/1_gitops/restore-urls.sh` |
| Restore GitHub remote only | Main repository | `./assets/1_gitops/restore-github-remote.sh` |
| **Verify Configuration** | | |
| Check current repository | Either | `git remote -v` |
| Check ArgoCD applications | Cluster | `oc get applications -n openshift-gitops` |

---

## Directory Structure

```
1_gitops/
├── developerhub/              # Red Hat Developer Hub installation
│   ├── manifests/             # RHDH operator and instance manifests
│   ├── argocd-application.yaml
│   └── README.md
├── kafka/                     # AMQ Streams (Kafka) operator installation
│   ├── manifests/             # Kafka operator manifests
│   ├── argocd-application.yaml
│   └── README.md
├── namespaces/                # Namespace definitions and configurations
│   ├── manifests/             # Playground namespace and policies
│   ├── argocd-application.yaml
│   └── README.md
├── apps/                      # App-of-Apps child application definitions
│   ├── 01-playground-namespaces.yaml
│   ├── 02-kafka-operator.yaml
│   └── 03-developer-hub.yaml
├── playground-apps.yaml       # App-of-Apps parent application
├── setup-gitops-repo.sh       # Upload manifests to Gitea (replaces GITEA_URL with actual URL)
├── deploy-to-argocd.sh        # Deploy ArgoCD Applications
├── upload-and-deploy.sh       # Complete workflow: upload + deploy
├── restore-urls.sh            # Restore GITEA_URL placeholders (undo setup-gitops-repo.sh)
├── restore-github-remote.sh   # Restore GitHub remote in main repository
├── cleanup-for-github.sh      # Complete cleanup (runs restore-urls + restore-github-remote)
└── README.md                  # This file
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

## Quick Start - Complete Workflow

### One-Step Deployment (Recommended)

For a complete automated workflow that uploads manifests to Gitea AND deploys to ArgoCD:

```bash
cd assets/1_gitops
./upload-and-deploy.sh
```

This single script will:
1. Upload all GitOps manifests to Gitea repository
2. Update all ArgoCD Application manifests with correct repository URLs
3. Deploy ArgoCD Applications using App-of-Apps pattern
4. Verify deployment status

### Manual Step-by-Step Workflow

If you prefer to run steps individually:

#### Step 1: Upload to Gitea

```bash
cd assets/1_gitops
./setup-gitops-repo.sh
```

#### Step 2: Deploy to ArgoCD

```bash
cd assets/1_gitops
./deploy-to-argocd.sh
# Select option 2 for App-of-Apps pattern
```

## GitOps Repository Setup

### Prerequisites

Before running any scripts, ensure:
- Gitea is installed and running in the `gitea` namespace
- OpenShift GitOps (ArgoCD) is installed and running
- `oc` CLI is installed and you're logged into OpenShift
- `git`, `curl`, and `jq` are installed

### What the Script Does

The `setup-gitops-repo.sh` script automatically:

1. **Checks Prerequisites**: Verifies required tools are installed
2. **Connects to Gitea**: Gets the Gitea route and tests connectivity
3. **Authenticates**: Uses admin credentials to access Gitea API
4. **Creates Repository**: Creates `playground-gitops` repository (if not exists)
5. **Initializes Git**: Sets up local git repository
6. **Updates ArgoCD URLs**: Automatically replaces placeholder repository URLs in all `argocd-application.yaml` files with the actual Gitea repository URL
7. **Adds Remote**: Configures Gitea as git remote
8. **Commits Changes**: Commits all GitOps manifests
9. **Pushes to Gitea**: Pushes content to the repository

**Important**: The script automatically updates all ArgoCD Application manifests with the correct Gitea repository URL, so you don't need to manually edit them.

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

## Deploying to ArgoCD

After setting up the Gitea repository, deploy all manifests using ArgoCD.

### Complete Workflow Script

The `upload_and_deploy.sh` script combines both repository setup and ArgoCD deployment:

```bash
cd assets/1_gitops
./upload-and-deploy.sh
```

**What it does:**
1. Uploads all GitOps manifests to Gitea
2. Updates all ArgoCD Application manifests with correct Gitea URLs
3. Deploys ArgoCD Applications using App-of-Apps pattern
4. Verifies deployment status
5. Displays comprehensive summary with access URLs

**This is the recommended approach for first-time setup.**

### Deployment-Only Script

If you've already run `setup-gitops-repo.sh`, use the deployment script:

```bash
cd assets/1_gitops
./deploy-to-argocd.sh
```

**What it does:**
1. Verifies ArgoCD is running
2. Gets Gitea repository URL
3. Creates ArgoCD Applications for:
   - `playground-namespaces` - Namespace configuration
   - `kafka-operator` - Kafka operator
   - `developer-hub` - Developer Hub
4. Syncs all applications
5. Displays deployment summary

Choose between:
- **Individual Applications** (option 1) - Recommended for learning
- **App-of-Apps** (option 2) - Advanced GitOps pattern (used by upload_and_deploy.sh)

See the "Deployment Patterns Explained" section below for detailed comparison.

### Manual Deployment

Create applications manually if needed (see "Manual Setup" section below for examples).

## Deployment Patterns Explained

Understanding the two ArgoCD deployment patterns and when to use each.

### Individual Applications Pattern

**What it is:**
Each component is deployed as a separate, independent ArgoCD Application. You manually create Application manifests for each component (namespaces, kafka-operator, developer-hub).

**Architecture:**
```
ArgoCD
├── Application: playground-namespaces
│   └── Syncs: namespaces/manifests/**
├── Application: kafka-operator
│   └── Syncs: kafka/manifests/**
└── Application: developer-hub
    └── Syncs: developerhub/manifests/**
```

**Pros:**
- ✅ **Simple and straightforward** - Easy to understand for beginners
- ✅ **Full control** - Each app has independent configuration
- ✅ **Easy troubleshooting** - Issues are isolated to specific apps
- ✅ **Flexible sync policies** - Different settings per component
- ✅ **Independent lifecycle** - Deploy/delete apps independently
- ✅ **Clear visibility** - See each component separately in ArgoCD UI
- ✅ **Better for learning** - Understand ArgoCD concepts step-by-step
- ✅ **No dependencies** - Apps don't depend on each other
- ✅ **Selective deployment** - Deploy only what you need

**Cons:**
- ❌ **Manual management** - Need to create each Application manifest
- ❌ **Repetitive configuration** - Similar settings across apps
- ❌ **More YAML** - One Application manifest per component
- ❌ **Scaling challenges** - Adding 50 apps means 50 manifests
- ❌ **No automatic discovery** - New components require manual app creation
- ❌ **Harder to bootstrap** - Must apply multiple manifests to get started

**When to use:**
- 🎓 **Learning ArgoCD** - Best for understanding fundamentals
- 🔧 **Small deployments** - Few components (< 10 apps)
- 🎯 **Specific requirements** - Each app needs unique configuration
- 🐛 **Troubleshooting** - Need isolation for debugging
- 🧪 **Testing** - Experimenting with different sync strategies
- 👥 **Multi-team** - Different teams own different apps

**Example:**
```yaml
# Manually create each application
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kafka-operator
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://gitea.../playground-gitops.git
    path: kafka/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: kafka
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### App-of-Apps Pattern

**What it is:**
A single "parent" Application that automatically discovers and manages multiple "child" Applications. The parent app looks for `argocd-application.yaml` files in your repository and creates Applications from them.

**Architecture:**
```
ArgoCD
└── Application: playground-apps (App-of-Apps)
    ├── Discovers: developerhub/argocd-application.yaml
    │   └── Creates Application: developer-hub
    │       └── Syncs: developerhub/manifests/**
    ├── Discovers: kafka/argocd-application.yaml
    │   └── Creates Application: kafka-operator
    │       └── Syncs: kafka/manifests/**
    └── Discovers: namespaces/argocd-application.yaml
        └── Creates Application: playground-namespaces
            └── Syncs: namespaces/manifests/**
```

**Pros:**
- ✅ **Automatic discovery** - New apps auto-deploy when added to Git
- ✅ **Single entry point** - One app to manage all children
- ✅ **GitOps best practice** - Declarative app management
- ✅ **Scalable** - Easily manage 50+ applications
- ✅ **DRY principle** - No repetitive Application manifests
- ✅ **Easy bootstrap** - Single command deploys everything
- ✅ **Self-service** - Teams add apps by committing YAML to Git
- ✅ **Hierarchical structure** - Organize apps logically
- ✅ **Environment parity** - Same pattern across dev/staging/prod

**Cons:**
- ❌ **More complex** - Requires understanding of nested apps
- ❌ **Harder to debug** - Issues cascade from parent to children
- ❌ **All or nothing** - Deleting parent deletes all children
- ❌ **Sync dependencies** - Parent must sync before children
- ❌ **Additional files** - Need `argocd-application.yaml` in each component
- ❌ **Less visibility** - Children nested under parent in UI
- ❌ **Learning curve** - Advanced pattern, not beginner-friendly
- ❌ **Potential recursion** - Misconfiguration can cause loops

**When to use:**
- 🏢 **Production environments** - Standard pattern for enterprises
- 📈 **Large scale** - Managing many applications (> 10)
- 🚀 **Platform teams** - Building internal platforms
- 🔄 **Continuous delivery** - Fully automated deployments
- 🌍 **Multi-environment** - Same pattern across environments
- 👥 **Self-service** - Enable teams to deploy independently
- 📦 **Microservices** - Many small services to manage

**Example:**
```yaml
# Parent App-of-Apps
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: playground-apps
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://gitea.../playground-gitops.git
    path: .
    directory:
      recurse: false
      include: '*/argocd-application.yaml'  # Auto-discover children
  destination:
    server: https://kubernetes.default.svc
    namespace: openshift-gitops
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### Comparison Matrix

| Feature | Individual Apps | App-of-Apps |
|---------|----------------|-------------|
| **Complexity** | Low | High |
| **Setup Time** | Medium | Fast (after setup) |
| **Learning Curve** | Gentle | Steep |
| **Scalability** | Poor (>10 apps) | Excellent |
| **Flexibility** | High | Medium |
| **Isolation** | Excellent | Poor |
| **Auto-discovery** | No | Yes |
| **GitOps Maturity** | Basic | Advanced |
| **Troubleshooting** | Easy | Harder |
| **Production Ready** | Yes | Yes |
| **Best For** | Learning, Small Scale | Production, Large Scale |

---

### Hybrid Approach

You can also combine both patterns:

**Example:**
```
ArgoCD
├── Application: core-infrastructure (Individual)
│   └── Syncs: Core infrastructure components
├── Application: platform-apps (App-of-Apps)
│   ├── Discovers platform services
│   └── Auto-manages platform components
└── Application: tenant-apps (App-of-Apps)
    ├── Discovers tenant applications
    └── Auto-manages tenant workloads
```

**When to use hybrid:**
- Critical infrastructure needs individual control
- Platform services use App-of-Apps for scalability
- Different teams have different needs
- Gradual migration from Individual to App-of-Apps

---

### Decision Guide

**Choose Individual Applications if:**
- You're new to ArgoCD
- You have < 10 applications
- Each app needs unique configuration
- You want maximum control and visibility
- You're learning GitOps concepts

**Choose App-of-Apps if:**
- You're comfortable with ArgoCD
- You have > 10 applications
- You want automatic discovery
- You're implementing enterprise GitOps
- You need self-service for teams
- You want to follow GitOps best practices

**Start with Individual, migrate to App-of-Apps:**
1. Learn ArgoCD with Individual Applications
2. Understand sync policies and health checks
3. Once comfortable, migrate to App-of-Apps
4. Enjoy automatic discovery and scaling

---

### Migration Path

**From Individual to App-of-Apps:**

1. **Prepare repository:**
   ```bash
   # Add argocd-application.yaml to each component
   # Example: developerhub/argocd-application.yaml
   ```

2. **Create App-of-Apps:**
   ```bash
   # Deploy parent application
   oc apply -f app-of-apps.yaml
   ```

3. **Verify children created:**
   ```bash
   # Check that child apps were discovered
   oc get applications -n openshift-gitops
   ```

4. **Remove individual apps:**
   ```bash
   # Once children are syncing, remove old apps
   oc delete application kafka-operator -n openshift-gitops
   # (Only if not using finalizers)
   ```

---

### Recommendation for This Playground

**For learning:** Start with **Individual Applications** (Option 1)
- Understand each component independently
- Learn ArgoCD sync policies
- Practice troubleshooting

**For production use:** Migrate to **App-of-Apps** (Option 2)
- Scale to more components
- Enable team self-service
- Follow enterprise patterns

The `deploy-to-argocd.sh` script supports both patterns, so you can try each and see which fits your needs best!

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
