# Installation Walkthrough - What Happens Step by Step

> **📍 Important**: The `install.sh` script can be executed from **anywhere** - it automatically navigates to the correct directory.

## Overview

This interactive installation script sets up:
- **Red Hat OpenShift GitOps (ArgoCD)** - GitOps continuous delivery tool
- **Gitea** (optional) - Lightweight self-hosted Git server
- **GitHub Integration** (optional) - Connect to external GitHub organizations

You'll choose which Git server option you want during installation.

---

## BEFORE You Run install.sh

### Prerequisites:

1. **OpenShift Cluster Access**
   - You must be logged into an OpenShift cluster
   - Get login command: OpenShift Console → Click username → "Copy login command"

2. **Required Tools Installed**
   - `oc` CLI (OpenShift command-line tool)
   - `helm` CLI (version 3.x)
   - The script will check for these and provide installation instructions if missing

3. **For GitHub Integration (Optional)**
   - GitHub organization or user account
   - Personal Access Token with `repo` and `read:org` scopes
   - Create at: https://github.com/settings/tokens

### No Pre-Configuration Required!

Unlike the previous GitLab setup, **no template files need to be copied or edited**. The script handles everything interactively.

---

## What Happens When You Run ./install.sh

### Phase 1: Pre-Installation Checks

1. **Environment Validation**
   - Checks if `oc` CLI is installed
   - Checks if `helm` CLI is installed
   - Verifies you're logged into OpenShift cluster
   - Displays your current user and cluster

2. **Installation Options**
   - Presents three Git server options:
     1. **Install Gitea** - Local Git server on OpenShift
     2. **Use GitHub** - External GitHub organization
     3. **ArgoCD Only** - Skip Git server (configure manually later)

3. **Interactive Configuration**

   **If you choose Gitea (Option 1):**
   - No additional input needed
   - Script will automatically install and configure Gitea

   **If you choose GitHub (Option 2):**
   - Prompts for GitHub organization or username
   - Prompts for repository name (optional - leave empty for org-wide access)
   - Prompts for Personal Access Token (input hidden for security)

   **If you choose ArgoCD Only (Option 3):**
   - Skips Git server installation
   - You'll configure repositories manually later

4. **Confirmation**
   - Shows summary of what will be installed
   - Asks for final confirmation (y/n)

---

### Phase 2: Installation Steps

#### Part 1: ArgoCD Installation (Steps 1-7)

- **Step 1/7**: Create `openshift-gitops` namespace
- **Step 2/7**: Create OperatorGroup for GitOps operator
- **Step 3/7**: Subscribe to Red Hat OpenShift GitOps Operator
  - Waits for operator to be ready (1-3 minutes)
- **Step 4/7**: Apply ArgoCD admin password secret
  - Sets password: `argocd1234!!`
- **Step 5/7**: Deploy ArgoCD instance
  - Waits for ArgoCD to be ready (2-4 minutes)
- **Step 6/7**: Apply ArgoCD configuration ConfigMaps
  - Repository configurations
  - General settings
  - RBAC policies
- **Step 7/7**: Wait for all ArgoCD components to be ready
  - ArgoCD server
  - Repo server
  - Application controller

#### Part 2: Gitea Installation (If Option 1 Selected)

- **Step 1/6**: Add Gitea Helm repository
- **Step 2/6**: Create `gitea` namespace
- **Step 3/6**: Configure OpenShift security
  - Grants `anyuid` SCC to Gitea service accounts
- **Step 4/6**: Get cluster domain
  - Auto-detects your OpenShift cluster domain
- **Step 5/6**: Create Gitea Helm values file
  - Admin user: `admin`
  - Admin password: `gitea1234!`
  - SQLite database (lightweight)
  - Persistence enabled (10Gi)
- **Step 6/6**: Install Gitea via Helm
  - Waits for Gitea to be ready (2-3 minutes)
  - Creates OpenShift route for external access

#### Part 3: GitHub Integration (If Option 2 Selected)

- Creates ArgoCD repository secret with GitHub credentials
- Configures organization-wide or single-repository access
- ArgoCD can now access your GitHub repositories

#### Part 4: Post-Installation

- **Retrieves URLs**
  - ArgoCD route URL
  - Gitea route URL (if installed)

- **Displays Summary Table**
  ```
  ╔═══════════════════════════════════════════════════════════════╗
  ║              ACCESS CREDENTIALS SUMMARY                       ║
  ╠═══════════════╦═══════════════════════════════════════════════╣
  ║ ArgoCD        ║ Route: https://...                            ║
  ║               ║ Username: admin                               ║
  ║               ║ Password: argocd1234!!                           ║
  ╠═══════════════╬═══════════════════════════════════════════════╣
  ║ Gitea         ║ Route: https://...                            ║
  ║               ║ Username: admin                               ║
  ║               ║ Password: gitea1234!                          ║
  ╚═══════════════╩═══════════════════════════════════════════════╝
  ```

- **Creates Environment Config File**
  - Saves credentials to `/info/environment_config.md`
  - Contains actual URLs for your environment
  - Includes verification commands and next steps

---

## After Installation

### What You Can Do Immediately:

#### 1. Access ArgoCD

```bash
# Get URL (shown in installation output)
echo "https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"

# Login options:
# - Username: admin / Password: argocd1234!!
# - OR click "Log in via OpenShift" to use your OpenShift credentials
```

#### 2. Access Gitea (If Installed)

```bash
# Get URL
echo "https://$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')"

# Login:
# - Username: admin
# - Password: gitea1234!

# Create your first repository:
# 1. Click "+" in top-right
# 2. Select "New Repository"
# 3. Fill in details and create
```

#### 3. Use GitHub Integration (If Configured)

Your GitHub repositories are automatically available in ArgoCD:
- Create new ArgoCD Application
- Select your GitHub repository URL
- ArgoCD uses the configured credentials automatically

#### 4. Create Your First ArgoCD Application

**Using Gitea:**
```bash
# Via ArgoCD UI:
# 1. Click "NEW APP"
# 2. Repository URL: https://gitea-gitea.apps.<your-domain>/<user>/<repo>
# 3. Path: Directory with Kubernetes manifests
# 4. Cluster: https://kubernetes.default.svc
# 5. Namespace: target namespace
```

**Using GitHub:**
```bash
# Via ArgoCD UI:
# 1. Click "NEW APP"
# 2. Repository URL: https://github.com/<org>/<repo>
# 3. Path: Directory with Kubernetes manifests
# 4. Cluster: https://kubernetes.default.svc
# 5. Namespace: target namespace
```

---

## Time Estimates

| Phase | Time |
|-------|------|
| Pre-installation (reading docs, login) | 2-5 minutes |
| ArgoCD installation | 3-6 minutes |
| Gitea installation (if selected) | 2-4 minutes |
| GitHub configuration (if selected) | 1 minute |
| **Total** | **~8-16 minutes** |

Gitea is significantly faster than the previous GitLab setup!

---

## Common Questions

### Q: Do I need to prepare any configuration files?
**A:** No! The script is fully interactive. Just run it and answer the prompts.

### Q: Can I use both Gitea and GitHub?
**A:** The script installs one or the other during installation. However, you can manually add additional Git repositories to ArgoCD later through the UI or CLI.

### Q: What if I choose "ArgoCD Only"?
**A:** You can add Git repositories manually later:
- Via ArgoCD UI: Settings → Repositories → Connect Repo
- Via ArgoCD CLI: `argocd repo add <repo-url>`

### Q: Can I change the passwords?
**A:** Yes! See the "Changing Passwords" section in `/info/environment_config.md` or the main README.

### Q: What if Gitea pods fail to start?
**A:** The script automatically grants the required Security Context Constraints (SCC). If issues persist, check:
```bash
oc get pods -n gitea
oc describe pod <pod-name> -n gitea
oc get events -n gitea --sort-by='.lastTimestamp'
```

### Q: How do I verify the installation?
**A:** Run the verification commands shown at the end of installation:
```bash
# Check ArgoCD
oc get pods -n openshift-gitops
oc get argocd -n openshift-gitops

# Check Gitea (if installed)
oc get pods -n gitea
helm list -n gitea
```

### Q: Where are my credentials saved?
**A:** In two places:
1. **Terminal output** - Displayed at end of installation
2. **Environment config file** - `/info/environment_config.md` with your actual URLs

---

## Comparison with Previous GitLab Setup

| Feature | GitLab (Old) | Gitea (New) |
|---------|--------------|-------------|
| Pre-configuration required | Yes (template files, SSH keys) | No (fully interactive) |
| Installation time | 15-25 minutes | 8-16 minutes |
| Resource usage | 4-8 GB RAM | 512 MB - 1 GB RAM |
| Complexity | High (operator + custom resources) | Low (Helm chart) |
| OpenShift compatibility | Required workarounds | Native support |
| Security Context Constraints | Complex manual setup | Automated by script |

---

## Troubleshooting

If something goes wrong:

1. **Check the documentation**
   - `/info/environment_config.md` - Your environment details
   - `assets/0_initial_setup/README.md` - Detailed setup guide
   - `assets/0_initial_setup/QUICK_REFERENCE.md` - Command reference

2. **Verify resources**
   ```bash
   oc get all -n openshift-gitops
   oc get all -n gitea  # if Gitea was installed
   ```

3. **Check logs**
   ```bash
   # ArgoCD logs
   oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server

   # Gitea logs
   oc logs -n gitea -l app.kubernetes.io/name=gitea
   ```

4. **Reinstall if needed**
   - The script is idempotent - safe to run multiple times
   - Old `environment_config.md` is automatically removed on each run

---

## Next Steps

After successful installation:

1. ✅ Review the environment config: `/info/environment_config.md`
2. ✅ Access ArgoCD and Gitea UIs
3. ✅ Create your first repository (in Gitea) or use existing (from GitHub)
4. ✅ Create your first ArgoCD application
5. ✅ Explore GitOps workflows!

For detailed guides, see:
- [Main README](README.md)
- [Quick Reference Guide](QUICK_REFERENCE.md)
- [Environment Configuration](/info/environment_config.md)
