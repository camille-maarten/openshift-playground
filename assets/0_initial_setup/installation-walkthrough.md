# Installation Walkthrough - What Happens Step by Step

## BEFORE You Run install.sh

### What You MUST Do First:

1. **Copy the template file**
   ```bash
   cp manifests/15-gitlab-user-password-secret.yaml.template manifests/15-gitlab-user-password-secret.yaml
   ```

2. **(Optional) Add your SSH key**
   - Check: `ls ~/.ssh/id_*.pub`
   - If no key exists, create: `ssh-keygen -t ed25519 -C "your-email@example.com"`
   - Display: `cat ~/.ssh/id_ed25519.pub`
   - Edit file: `vim manifests/15-gitlab-user-password-secret.yaml`
   - Find line: `# ssh_public_key: PASTE_YOUR_SSH_PUBLIC_KEY_HERE`
   - Remove `#` and paste your key
   - Save and exit

3. **(Alternative) Skip SSH**
   - Just copy the template without editing
   - You'll use HTTPS with username/password instead

---

## What Happens When You Run ./install.sh

### Pre-Installation Checks:

1. **Check if you're logged into OpenShift**
   - Shows your username and cluster
   - If not logged in, tells you exactly how to get the login command

2. **Validates GitLab configuration file exists**
   - Checks for: `manifests/15-gitlab-user-password-secret.yaml`
   - If missing, shows DETAILED instructions with:
     - How to copy the template
     - How to check for SSH keys
     - How to create SSH keys
     - How to add SSH key to the file
     - Exact vim/nano commands to save
     - Alternative to skip SSH

3. **Shows installation summary**
   - What will be installed
   - Default credentials
   - Estimated time

4. **Asks for confirmation**
   - Type 'y' to proceed or 'n' to cancel

---

### Installation Steps (If You Confirm):

**Part 1: ArgoCD Installation (Steps 1-5)**

- **Step 1/12**: Create openshift-gitops namespace
- **Step 2/12**: Create OperatorGroup
- **Step 3/12**: Install Red Hat GitOps Operator (waits 2-5 min)
- **Step 4/12**: Apply ArgoCD admin password secret
- **Step 5/12**: Deploy ArgoCD instance (waits 3-5 min)
- Apply ArgoCD ConfigMaps

**Part 2: GitLab Installation (Steps 6-11)**

- **Step 6/12**: Create gitlab-system namespace
- **Step 7/12**: Create GitLab OperatorGroup
- **Step 8/12**: Install GitLab Operator (waits 2-5 min)
- **Step 9/12**: Apply GitLab secrets (including YOUR SSH key!)
- **Step 10/12**: Apply GitLab ConfigMap
- **Step 11/12**: Deploy GitLab instance (waits 5-10 min)
- Apply GitLab routes

**Part 3: Integration (Step 12)**

- **Step 12/12**: Auto-configure ArgoCD to use GitLab
  - Creates secret with GitLab credentials
  - ArgoCD can now access all GitLab repos automatically

---

### Final Output:

Shows you:
- ✓ ArgoCD URL
- ✓ ArgoCD credentials (admin / argo1234!)
- ✓ GitLab URL
- ✓ GitLab credentials (root / gitlab1234!)
- ✓ Status check commands
- ✓ Next steps

---

## After Installation

### What You Can Do Immediately:

1. **Access ArgoCD**
   - URL shown in output
   - Login with: admin / argo1234!

2. **Access GitLab**
   - URL shown in output
   - Login with: root / gitlab1234!

3. **If you added SSH key:**
   - Your SSH key is already in GitLab!
   - Clone repos with SSH: `git clone git@gitlab...`

4. **If you skipped SSH:**
   - Clone repos with HTTPS: `git clone https://gitlab...`
   - Use credentials: root / gitlab1234!
   - Add SSH key later in GitLab UI → User Settings → SSH Keys

---

## Total Time Estimate:

- Pre-setup: 2-5 minutes
- Installation: 10-15 minutes
- **Total: ~15-20 minutes**

---

## Common Questions:

**Q: What if I don't have an SSH key?**
A: The script shows you EXACTLY how to create one, or you can skip it and use HTTPS.

**Q: What if I skip SSH key setup?**
A: No problem! You can use HTTPS, or add SSH key later via GitLab UI.

**Q: What if I mess up the configuration file?**
A: Just delete it and copy the template again:
```bash
rm manifests/15-gitlab-user-password-secret.yaml
cp manifests/15-gitlab-user-password-secret.yaml.template manifests/15-gitlab-user-password-secret.yaml
```

**Q: Can I change passwords later?**
A: Yes! Edit the secret files and reapply them, then restart the pods.

**Q: Do I need GitHub credentials?**
A: No! ArgoCD automatically works with the local GitLab. GitHub is optional (see Appendix).
