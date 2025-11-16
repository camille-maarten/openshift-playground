# ArgoCD and GitLab Quick Reference

## Quick Installation

### BEFORE INSTALLATION: Setup Required (ONE TIME ONLY)

```bash
# Step 1: Copy the GitLab configuration template
cp manifests/15-gitlab-user-password-secret.yaml.template manifests/15-gitlab-user-password-secret.yaml

# Step 2: (OPTIONAL) Add your SSH public key for Git access
# Check if you have an SSH key:
ls ~/.ssh/id_*.pub

# If you DON'T have one, create it (press ENTER for all prompts):
ssh-keygen -t ed25519 -C "your-email@example.com"

# Display your public key:
cat ~/.ssh/id_ed25519.pub
# Copy the entire output (starts with ssh-ed25519...)

# Step 3: Edit the configuration file
vim manifests/15-gitlab-user-password-secret.yaml
# OR: nano manifests/15-gitlab-user-password-secret.yaml

# Find this line:
#   # ssh_public_key: PASTE_YOUR_SSH_PUBLIC_KEY_HERE
# Remove the '#' and paste your public key:
#   ssh_public_key: ssh-ed25519 AAAAC3NzaC... your-email@example.com

# Save: ESC then :wq (vim) or CTRL+X then Y (nano)

# ALTERNATIVE: Skip SSH and use HTTPS only (no editing needed)
# Just copy the template as-is in Step 1
```

### Run Installation

```bash
# Make script executable (first time only)
chmod +x install.sh

# Run installation (installs both ArgoCD and GitLab with automatic integration)
./install.sh

# Default credentials:
# - ArgoCD: admin / argo1234!
# - GitLab: root / gitlab1234!
```

**Installation time**: ~10-15 minutes

**Note**: If you skip SSH setup, you can add your SSH key later via GitLab UI (User Settings → SSH Keys).

## Getting OpenShift Login Command

1. Open OpenShift Web Console
2. Click your username (top-right)
3. Select "Copy login command"
4. Click "Display Token"
5. Copy and run the `oc login` command

## Common Commands

### ArgoCD Access Information

```bash
# Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Admin password (default)
echo "argo1234!"

# Admin username
echo "admin"
```

### GitLab Access Information

```bash
# Get GitLab URL
oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}'

# Root password (default)
echo "gitlab1234!"

# Root username
echo "root"
```

### ArgoCD Monitoring

```bash
# Check ArgoCD instance
oc get argocd -n openshift-gitops

# Check all pods
oc get pods -n openshift-gitops

# Watch pods
oc get pods -n openshift-gitops -w

# Check operator status
oc get csv -n openshift-gitops
```

### GitLab Monitoring

```bash
# Check GitLab instance
oc get gitlab -n gitlab-system

# Check all pods
oc get pods -n gitlab-system

# Watch pods
oc get pods -n gitlab-system -w

# Check operator status
oc get csv -n gitlab-system

# Check routes
oc get routes -n gitlab-system

# Check persistent volume claims
oc get pvc -n gitlab-system
```

### ArgoCD Logs

```bash
# Server logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server --tail=100 -f

# Application controller logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller --tail=100 -f

# Repo server logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-repo-server --tail=100 -f
```

### GitLab Logs

```bash
# Webservice logs
oc logs -n gitlab-system -l app=webservice --tail=100 -f

# Sidekiq logs
oc logs -n gitlab-system -l app=sidekiq --tail=100 -f

# GitLab Shell logs
oc logs -n gitlab-system -l app=gitlab-shell --tail=100 -f

# Gitaly logs
oc logs -n gitlab-system -l app=gitaly --tail=100 -f

# PostgreSQL logs
oc logs -n gitlab-system -l app=postgresql --tail=100 -f

# Registry logs
oc logs -n gitlab-system -l app=registry --tail=100 -f
```

### Restart ArgoCD Components

```bash
# Restart ArgoCD server
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops

# Restart application controller
oc delete pod -l app.kubernetes.io/name=openshift-gitops-application-controller -n openshift-gitops

# Restart repo server
oc delete pod -l app.kubernetes.io/name=openshift-gitops-repo-server -n openshift-gitops
```

### Restart GitLab Components

```bash
# Restart GitLab webservice
oc delete pod -l app=webservice -n gitlab-system

# Restart Sidekiq
oc delete pod -l app=sidekiq -n gitlab-system

# Restart GitLab Shell
oc delete pod -l app=gitlab-shell -n gitlab-system

# Restart all GitLab components (use with caution)
oc delete pods --all -n gitlab-system
```

### ArgoCD CLI

```bash
# Get route
ARGOCD_ROUTE=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')

# Login (default password: argo1234!)
argocd login $ARGOCD_ROUTE --username admin --password argo1234! --insecure

# List applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# Add repository
argocd repo add https://github.com/your-org/your-repo
```

### GitLab CLI

```bash
# Get GitLab URL
GITLAB_URL=$(oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}')

# Create personal access token via UI first (User Settings → Access Tokens)
# Then configure glab
glab auth login --hostname $GITLAB_URL

# List projects
glab project list

# Clone a project
glab repo clone <project-name>

# Create a new project
glab project create <project-name>

# List merge requests
glab mr list

# Create a merge request
glab mr create
```

### Managing ArgoCD Secrets

```bash
# Update admin password
vim manifests/10-admin-password-secret.yaml
oc apply -f manifests/10-admin-password-secret.yaml
# Restart ArgoCD server for password change to take effect
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops

# View automatically configured GitLab integration
oc get secret gitlab-repo-credentials -n openshift-gitops -o yaml

# Add GitHub or external Git (optional - see README Appendix)
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
vim manifests/08-git-credentials-secret.yaml
oc apply -f manifests/08-git-credentials-secret.yaml

# List secrets
oc get secrets -n openshift-gitops

# Delete a secret
oc delete secret <secret-name> -n openshift-gitops
```

### Managing GitLab Secrets

```bash
# Update GitLab root password
vim manifests/14-gitlab-root-password-secret.yaml
oc apply -f manifests/14-gitlab-root-password-secret.yaml
# Restart GitLab webservice for password change to take effect
oc delete pod -l app=webservice -n gitlab-system

# List secrets
oc get secrets -n gitlab-system

# Delete a secret
oc delete secret <secret-name> -n gitlab-system
```

### Managing ArgoCD Applications

```bash
# List ArgoCD applications
oc get applications -n openshift-gitops

# Get application details
oc get application <app-name> -n openshift-gitops -o yaml

# Delete an application
oc delete application <app-name> -n openshift-gitops
```

### ArgoCD Troubleshooting

```bash
# Check recent events
oc get events -n openshift-gitops --sort-by='.lastTimestamp'

# Describe a pod
oc describe pod <pod-name> -n openshift-gitops

# Check route
oc describe route openshift-gitops-server -n openshift-gitops

# Get all resources
oc get all -n openshift-gitops

# Check ArgoCD instance details
oc describe argocd openshift-gitops -n openshift-gitops
```

### GitLab Troubleshooting

```bash
# Check recent events
oc get events -n gitlab-system --sort-by='.lastTimestamp'

# Describe a pod
oc describe pod <pod-name> -n gitlab-system

# Check routes
oc describe route gitlab -n gitlab-system

# Get all resources
oc get all -n gitlab-system

# Check GitLab instance details
oc describe gitlab gitlab -n gitlab-system

# Check PVC status (common issue)
oc get pvc -n gitlab-system
oc describe pvc <pvc-name> -n gitlab-system

# Check if migrations completed
oc logs -n gitlab-system -l app=migrations --tail=100
```

### Cleanup (Uninstall)

**ArgoCD:**

```bash
# Delete ArgoCD instance
oc delete argocd openshift-gitops -n openshift-gitops

# Delete subscription
oc delete subscription openshift-gitops-operator -n openshift-gitops

# Delete operator group
oc delete operatorgroup openshift-gitops-operator -n openshift-gitops

# Delete CSV (if needed)
oc delete csv -n openshift-gitops --all

# Delete namespace (WARNING: This deletes everything)
oc delete namespace openshift-gitops
```

**GitLab:**

```bash
# Delete GitLab instance
oc delete gitlab gitlab -n gitlab-system

# Delete subscription
oc delete subscription gitlab-operator-kubernetes -n gitlab-system

# Delete operator group
oc delete operatorgroup gitlab-operator -n gitlab-system

# Delete CSV (if needed)
oc delete csv -n gitlab-system --all

# Delete PVCs (WARNING: This deletes all data)
oc delete pvc --all -n gitlab-system

# Delete namespace (WARNING: This deletes everything)
oc delete namespace gitlab-system
```

## Example: Deploy First Application

```bash
# Create a simple ArgoCD application
cat <<EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-first-app
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-repo
    targetRevision: HEAD
    path: k8s/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

## Using GitLab with ArgoCD

**GitLab is automatically integrated!** ArgoCD is pre-configured to access all GitLab repositories.

### Create and Use a GitLab Repository

```bash
# 1. Create a project in GitLab UI (https://[gitlab-route])
# 2. Clone the repository
GITLAB_URL=$(oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}')
git clone https://$GITLAB_URL/root/my-project.git

# 3. Add Kubernetes manifests
cd my-project
mkdir manifests
# Add your YAML files to manifests/

# 4. Commit and push
git add .
git commit -m "Add Kubernetes manifests"
git push

# 5. Create ArgoCD application pointing to GitLab
cat <<EOF | oc apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: https://gitlab-webservice-default.gitlab-system.svc.cluster.local/root/my-project.git
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF
```

### Adding External Git (GitHub, etc.)

See the **Appendix: Using External Git Providers** in README.md for detailed instructions on adding GitHub, Bitbucket, or other Git services.

## Useful Links

- **ArgoCD UI**: Get URL with `oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'`
- **GitLab UI**: Get URL with `oc get route gitlab -n gitlab-system -o jsonpath='{.spec.host}'`
- **Documentation**: See README.md
- **ArgoCD Support**: https://docs.openshift.com/container-platform/latest/cicd/gitops/
- **GitLab Docs**: https://docs.gitlab.com/ee/
