# Quick Reference Guide - ArgoCD with Gitea/GitHub

> **📍 Important**: Commands with "(run from repository root)" should be executed from the repository root directory. The `install.sh` script can be run from **anywhere** - it automatically changes to the correct directory.

## Installation Commands

### Quick Install (Automated)
```bash
# From repository root
bash assets/0_initial_setup/install.sh
```

The script will prompt you to choose:
1. Install Gitea (local Git server)
2. Use external GitHub repository
3. Skip Git server (ArgoCD only)

### Manual ArgoCD Installation
```bash
cd assets/0_initial_setup
oc apply -f manifests/01-namespace.yaml
oc apply -f manifests/02-operatorgroup.yaml
oc apply -f manifests/03-subscription.yaml
oc apply -f manifests/10-admin-password-secret.yaml
oc apply -f manifests/04-argocd-instance.yaml
oc apply -f manifests/05-argocd-repositories-configmap.yaml
oc apply -f manifests/06-argocd-cm-configmap.yaml
oc apply -f manifests/07-argocd-rbac-configmap.yaml
```

### Install Gitea Manually
```bash
helm repo add gitea-charts https://dl.gitea.com/charts/
helm repo update
oc create namespace gitea
CLUSTER_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')

# Create Gitea values file
cat > /tmp/gitea-values.yaml <<EOF
gitea:
  admin:
    username: admin
    password: gitea1234!
    email: admin@gitea.local
  config:
    server:
      DOMAIN: gitea-http.gitea.svc.cluster.local
      ROOT_URL: https://gitea-gitea.${CLUSTER_DOMAIN}/
    database:
      DB_TYPE: sqlite3
    security:
      INSTALL_LOCK: true
service:
  http:
    type: ClusterIP
    port: 3000
ingress:
  enabled: false
persistence:
  enabled: true
  size: 10Gi
postgresql:
  enabled: false
redis-cluster:
  enabled: false
EOF

helm upgrade --install gitea gitea-charts/gitea \
  --namespace gitea \
  --values /tmp/gitea-values.yaml \
  --wait --timeout 600s

oc create route edge gitea --service=gitea-http --port=http -n gitea
```

### Configure GitHub Integration Manually
```bash
GITHUB_ORG="your-org"
GITHUB_TOKEN="your-token"

cat <<EOF | oc apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: github-org-${GITHUB_ORG}
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/${GITHUB_ORG}
  password: ${GITHUB_TOKEN}
  username: ${GITHUB_ORG}
EOF
```

## Access Information

### Get ArgoCD URL
```bash
echo "https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
```

### Get Gitea URL
```bash
echo "https://$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')"
```

### Default Credentials

**ArgoCD:**
- Username: `admin`
- Password: `argocd1234!`
- Or use "Log in via OpenShift"

**Gitea:**
- Username: `admin`
- Password: `gitea1234!`

## Common Operations

### Check ArgoCD Status
```bash
oc get pods -n openshift-gitops
oc get argocd -n openshift-gitops
oc get route openshift-gitops-server -n openshift-gitops
```

### Check Gitea Status
```bash
oc get pods -n gitea
helm list -n gitea
oc get route gitea -n gitea
```

### View ArgoCD Logs
```bash
oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server
oc logs -n openshift-gitops -l app.kubernetes.io/name=argocd-repo-server
oc logs -n openshift-gitops -l app.kubernetes.io/name=argocd-application-controller
```

### View Gitea Logs
```bash
oc logs -n gitea -l app.kubernetes.io/name=gitea
```

### Restart ArgoCD
```bash
oc rollout restart deployment -n openshift-gitops
```

### Restart Gitea
```bash
oc rollout restart deployment -n gitea gitea
```

## ArgoCD CLI Commands

### Install ArgoCD CLI
```bash
# macOS
brew install argocd

# Linux
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd
```

### Login to ArgoCD
```bash
ARGOCD_URL=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
argocd login $ARGOCD_URL --username admin --password argocd1234! --insecure
```

### Create Application
```bash
argocd app create my-app \
  --repo https://github.com/your-org/your-repo \
  --path manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

### Sync Application
```bash
argocd app sync my-app
```

### List Applications
```bash
argocd app list
```

### Get Application Details
```bash
argocd app get my-app
```

### Delete Application
```bash
argocd app delete my-app
```

## Git Repository Management

### Add Git Repository to ArgoCD (via CLI)
```bash
argocd repo add https://github.com/your-org/your-repo \
  --username your-username \
  --password your-token
```

### List Repositories
```bash
argocd repo list
```

### Remove Repository
```bash
argocd repo rm https://github.com/your-org/your-repo
```

### Test Repository Connection
```bash
oc exec -n openshift-gitops deployment/openshift-gitops-repo-server -- \
  git ls-remote https://github.com/your-org/your-repo
```

## Troubleshooting Commands

### Check Operator Status
```bash
oc get csv -n openshift-gitops
oc describe csv -n openshift-gitops
```

### Check All Resources
```bash
oc get all -n openshift-gitops
oc get all -n gitea
```

### View Events
```bash
oc get events -n openshift-gitops --sort-by='.lastTimestamp'
oc get events -n gitea --sort-by='.lastTimestamp'
```

### Check PersistentVolumeClaims
```bash
oc get pvc -n gitea
```

### Describe Pod
```bash
oc describe pod <pod-name> -n openshift-gitops
oc describe pod <pod-name> -n gitea
```

### Get Pod Shell
```bash
oc rsh -n openshift-gitops <pod-name>
oc rsh -n gitea <pod-name>
```

## Uninstallation

### Uninstall ArgoCD
```bash
oc delete argocd openshift-gitops -n openshift-gitops
oc delete subscription openshift-gitops-operator -n openshift-gitops
oc delete csv $(oc get csv -n openshift-gitops -o name | grep gitops) -n openshift-gitops
oc delete namespace openshift-gitops
```

### Uninstall Gitea
```bash
helm uninstall gitea -n gitea
oc delete pvc --all -n gitea
oc delete namespace gitea
```

### Remove GitHub Integration
```bash
oc delete secret github-org-YOUR_ORG -n openshift-gitops
```

## GitHub Personal Access Token

### Create Token
1. Go to: https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo`, `read:org`
4. Copy the generated token

### Test Token
```bash
curl -H "Authorization: token YOUR_TOKEN" https://api.github.com/user
```

## Useful Aliases

Add these to your `.bashrc` or `.zshrc`:

```bash
# ArgoCD
alias argocd-url='echo "https://$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath=\"{.spec.host}\")"'
alias argocd-pods='oc get pods -n openshift-gitops'
alias argocd-logs='oc logs -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server --tail=100 -f'

# Gitea
alias gitea-url='echo "https://$(oc get route gitea -n gitea -o jsonpath=\"{.spec.host}\")"'
alias gitea-pods='oc get pods -n gitea'
alias gitea-logs='oc logs -n gitea -l app.kubernetes.io/name=gitea --tail=100 -f'
```

## Configuration File Locations

- ArgoCD manifests: `assets/0_initial_setup/manifests/`
- Installation script: `assets/0_initial_setup/install.sh`
- Full documentation: `assets/0_initial_setup/README.md`

## Support

- ArgoCD Docs: https://argo-cd.readthedocs.io/
- Gitea Docs: https://docs.gitea.io/
- OpenShift GitOps: https://docs.openshift.com/container-platform/latest/cicd/gitops/
- GitHub Tokens: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
