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
   ```bash
   cd assets/0_initial_setup
   ./install.sh
   ```

   This interactive script will:
   - Install Red Hat OpenShift GitOps (ArgoCD)
   - Optionally install Gitea Git server
   - Configure authentication and RBAC
   - Set up default credentials

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
