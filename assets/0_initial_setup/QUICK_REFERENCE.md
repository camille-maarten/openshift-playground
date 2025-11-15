# ArgoCD Quick Reference

## Quick Installation

```bash
# First, prepare secret files
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
cp manifests/09-webhook-secret.yaml.template manifests/09-webhook-secret.yaml
# Edit files with your credentials or leave empty for now

# Make script executable (first time only)
chmod +x install.sh

# Run installation
./install.sh
```

## Getting OpenShift Login Command

1. Open OpenShift Web Console
2. Click your username (top-right)
3. Select "Copy login command"
4. Click "Display Token"
5. Copy and run the `oc login` command

## Common Commands

### Access Information

```bash
# Get ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'

# Admin password (default)
echo "argo1234!"

# Admin username
echo "admin"
```

### Monitoring

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

### Logs

```bash
# Server logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server --tail=100 -f

# Application controller logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-application-controller --tail=100 -f

# Repo server logs
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-repo-server --tail=100 -f
```

### Restart Components

```bash
# Restart ArgoCD server
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops

# Restart application controller
oc delete pod -l app.kubernetes.io/name=openshift-gitops-application-controller -n openshift-gitops

# Restart repo server
oc delete pod -l app.kubernetes.io/name=openshift-gitops-repo-server -n openshift-gitops
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

### Managing Secrets

```bash
# Create Git credentials from template
cp manifests/08-git-credentials-secret.yaml.template manifests/08-git-credentials-secret.yaml
# Edit the file with your credentials
vim manifests/08-git-credentials-secret.yaml
# Apply
oc apply -f manifests/08-git-credentials-secret.yaml

# Update admin password
vim manifests/10-admin-password-secret.yaml
oc apply -f manifests/10-admin-password-secret.yaml
# Restart ArgoCD server for password change to take effect
oc delete pod -l app.kubernetes.io/name=openshift-gitops-server -n openshift-gitops

# List secrets
oc get secrets -n openshift-gitops

# Delete a secret
oc delete secret <secret-name> -n openshift-gitops
```

### Managing Applications

```bash
# List ArgoCD applications
oc get applications -n openshift-gitops

# Get application details
oc get application <app-name> -n openshift-gitops -o yaml

# Delete an application
oc delete application <app-name> -n openshift-gitops
```

### Troubleshooting

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

### Cleanup (Uninstall)

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

## Useful Links

- **ArgoCD UI**: https://[your-route]/applications
- **Documentation**: See README.md
- **Support**: https://docs.openshift.com/container-platform/latest/cicd/gitops/
