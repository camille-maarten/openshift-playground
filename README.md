# OpenShift Playground

A comprehensive environment for exploring and learning Red Hat OpenShift GitOps (ArgoCD) and Git server integration.

## Getting Started

### Prerequisites
- Access to an OpenShift cluster
- `oc` CLI tool installed and configured
- Cluster admin privileges

### First Step: Initial Setup

Before exploring the playground scenarios, you need to set up the foundational components:

1. **Install ArgoCD and Gitea**

   **Option A - Complete Installation (Fastest):**
   ```bash
   cd assets/0_initial_setup
   ./install_complete.sh
   ```
   Automatically installs both ArgoCD and Gitea without prompts.

   **Option B - Interactive Installation (More Control):**
   ```bash
   cd assets/0_initial_setup
   ./install.sh
   ```
   Interactive script that lets you choose between Gitea, GitHub, or ArgoCD-only installation.

   What gets installed:
   - Red Hat OpenShift GitOps (ArgoCD)
   - Gitea Git server (complete install) or optional (interactive)
   - Authentication and RBAC configuration
   - Default credentials

2. **Review the Setup Documentation**
   - See [assets/0_initial_setup/README.md](assets/0_initial_setup/README.md) for detailed installation instructions
   - Check the `info/` folder after installation for environment-specific configuration

3. **Access Your Environment**
   - ArgoCD: Use credentials `admin` / `argocd1234!!` or `admin-user` / `argocd1234!`
   - Gitea: Use credentials `admin` / `gitea1234!`
   - Or use OpenShift OAuth for ArgoCD authentication

## Project Structure

```
openshift-playground/
├── assets/
│   ├── 0_initial_setup/       # Initial ArgoCD and Gitea setup
│   │   ├── README.md           # Detailed setup instructions
│   │   ├── install.sh          # Automated installation script
│   │   └── manifests/          # Kubernetes manifests
│   └── 1_gitops/               # GitOps manifests and deployment scripts
│       ├── README.md           # GitOps documentation
│       └── setup-gitops-repo.sh # Upload manifests to Gitea
├── info/                       # Generated environment configuration
├── release_notes/              # Version release notes
└── README.md                   # This file
```

## Important: Git Remote Configuration

**WARNING**: The GitOps setup creates a separate git repository for Gitea integration.

### Two Git Repositories

This project uses **two separate git repositories**:

1. **Main Repository** (GitHub)
   - Location: Repository root (`openshift-playground/.git`)
   - Remote: `origin` pointing to GitHub
   - Purpose: Source code development and version control

2. **GitOps Repository** (Gitea)
   - Location: `assets/1_gitops/.git`
   - Remote: `gitea` pointing to in-cluster Gitea
   - Purpose: ArgoCD manifest synchronization

### Before Committing to GitHub

**IMPORTANT**: Before pushing changes to GitHub, you must restore the GitHub remote configuration.

Run this script to ensure you're working with the correct repository:

```bash
./assets/1_gitops/restore-github-remote.sh
```

This script:
- Works with the main repository (not the GitOps subdirectory)
- Removes any Gitea remote from the main repository
- Ensures `origin` points to GitHub
- Verifies you're on the correct branch

**Always check your current branch before pushing:**

```bash
git branch           # Check current branch
git status          # Verify you're in the main repository
git remote -v       # Confirm origin points to GitHub
```

### Why Two Repositories?

- **Gitea Repository**: Used by ArgoCD to pull manifests from within the cluster
- **GitHub Repository**: Used for development, collaboration, and source control
- The `setup-gitops-repo.sh` script creates the Gitea repository and pushes manifests there
- The Gitea repository is local to the cluster and recreated per deployment
- The GitHub repository is the source of truth for the project

## What's Next?

After completing the initial setup:
1. Explore the ArgoCD UI and familiarize yourself with the interface
2. Create your first repository in Gitea
3. Deploy your first application using ArgoCD
4. Experiment with GitOps workflows and application synchronization

## Support

For issues or questions, please check:
- [Release Notes](release_notes/) for version-specific information
- [Initial Setup README](assets/0_initial_setup/README.md) for detailed configuration
- Generated documentation in the `info/` folder

## Version

Current Version: 0.0.1
