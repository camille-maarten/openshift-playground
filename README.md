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
│   └── 0_initial_setup/       # Initial ArgoCD and Gitea setup
│       ├── README.md           # Detailed setup instructions
│       ├── install.sh          # Automated installation script
│       └── manifests/          # Kubernetes manifests
├── info/                       # Generated environment configuration
├── release_notes/              # Version release notes
└── README.md                   # This file
```

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
