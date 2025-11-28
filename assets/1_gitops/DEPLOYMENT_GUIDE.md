# GitOps Deployment Guide

This guide explains how to deploy all GitOps applications to your OpenShift cluster using ArgoCD and Gitea.

## Overview

This deployment includes:
- **Keycloak (RHBK)**: Identity and Access Management with SSO
- **Red Hat Developer Hub**: Internal developer portal with Keycloak SSO integration
- **Kafka**: AMQ Streams operator for event streaming
- **Dev Spaces, Service Mesh, Serverless, and more**: Additional platform services

## Quick Start

### Complete Automated Deployment

From the repository root, run:

```bash
./run_complete.sh
```

This single command:
1. Installs OpenShift GitOps (ArgoCD) and Gitea
2. Uploads all GitOps manifests to Gitea with correct cluster URLs
3. Deploys all applications via ArgoCD App-of-Apps pattern
4. Waits for Keycloak and Developer Hub routes to be ready
5. Configures SSO integration between Keycloak and Developer Hub
6. Provides access URLs and credentials

**Estimated time**: 15-20 minutes

## Step-by-Step Deployment

If you prefer to run steps manually or need to troubleshoot:

### Step 1: Prerequisites

Ensure you have completed the initial setup:

```bash
cd assets/0_initial_setup
./install_complete.sh
```

This installs:
- OpenShift GitOps (ArgoCD)
- Gitea Git server
- Required credentials and RBAC

### Step 2: Upload Manifests to Gitea

```bash
cd assets/1_gitops
./upload-and-deploy.sh
```

This script:
1. Runs `setup-gitops-repo.sh` to:
   - Get Gitea route from your cluster
   - Replace `GITEA_URL` placeholders with actual cluster URLs
   - Create `playground-gitops` repository in Gitea
   - Push all manifests to Gitea
   - Restore template files locally for future commits

2. Runs `deploy-to-argocd.sh` to:
   - Create playground-apps (App-of-Apps)
   - ArgoCD discovers and deploys all child applications

### Step 3: Configure SSO (Optional but Recommended)

Wait for Keycloak and Developer Hub to be deployed (5-10 minutes), then:

```bash
cd assets/1_gitops
./update-keycloak-rhdh-config.sh
```

This configures:
- Keycloak redirect URIs for Developer Hub
- Developer Hub OIDC configuration with Keycloak URLs
- Automatic sync via ArgoCD

## Template Variables

The deployment uses template variables that are automatically replaced:

| Variable | Usage | Example |
|----------|-------|---------|
| `GITEA_URL` | All ArgoCD Application `repoURL` fields | `https://gitea-gitea.apps.cluster-xxx...` |
| `RHDH_BASE_URL` | Developer Hub app-config and Keycloak redirects | `https://backstage-developer-hub-rhdh.apps.cluster-xxx...` |
| `KEYCLOAK_BASE_URL` | Developer Hub OIDC configuration | `https://keycloak-ingress-keycloak.apps.cluster-xxx...` |

**Important**: Template files (with placeholders) are stored in Git. During deployment, they are replaced with actual URLs and pushed to Gitea. After pushing to Gitea, the local files are restored to template format for future commits.

## Accessing Deployed Applications

### Developer Hub with SSO

```bash
# Get Developer Hub URL
RHDH_URL=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}')
echo "Developer Hub: https://${RHDH_URL}"

# SSO Credentials
echo "Username: pe-user"
echo "Password: rhdh1234!"
```

### Keycloak Admin Console

```bash
# Get Keycloak URL and admin password
KEYCLOAK_URL=$(oc get route keycloak-ingress -n keycloak -o jsonpath='{.spec.host}')
KEYCLOAK_PASS=$(oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d)

echo "Keycloak Admin: https://${KEYCLOAK_URL}/admin"
echo "Username: admin"
echo "Password: ${KEYCLOAK_PASS}"
```

### ArgoCD

```bash
# Get ArgoCD URL
ARGOCD_URL=$(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
echo "ArgoCD: https://${ARGOCD_URL}"

# Credentials
echo "Username: admin"
echo "Password: argocd1234!!"
```

### Gitea

```bash
# Get Gitea URL
GITEA_URL=$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')
echo "Gitea: https://${GITEA_URL}"

# Credentials
echo "Username: admin"
echo "Password: gitea1234!"
```

## Application Status

Check deployment status:

```bash
# List all applications
oc get applications -n openshift-gitops

# Watch application sync status
watch oc get applications -n openshift-gitops

# Get detailed status of specific app
oc describe application keycloak -n openshift-gitops
```

## Deployed Components

### Core Applications

| Application | Namespace | Description |
|------------|-----------|-------------|
| playground-apps | openshift-gitops | App-of-Apps managing all child applications |
| playground-namespaces | openshift-gitops | Playground namespace with quotas and policies |
| keycloak | keycloak | Red Hat Build of Keycloak (RHBK) for SSO |
| developer-hub | rhdh | Red Hat Developer Hub with Keycloak SSO |
| kafka-operator | kafka | AMQ Streams (Kafka) operator |

### Additional Services

| Application | Namespace | Description |
|------------|-----------|-------------|
| devspaces | devspaces | Red Hat Dev Spaces (cloud IDE) |
| service-mesh | istio-system | Red Hat Service Mesh (Istio) |
| serverless | knative-serving | Red Hat Serverless (Knative) |
| openshift-ai | rhods-operator | Red Hat OpenShift AI |
| amq-broker | amq-broker | Red Hat AMQ Broker |
| elasticsearch | elasticsearch | Elasticsearch operator |
| jaeger | jaeger | Jaeger distributed tracing |

## Keycloak SSO Integration

### Overview

Developer Hub is pre-configured to use Keycloak for authentication via OpenID Connect (OIDC):

- **Realm**: `rhdh`
- **Client**: `rhdh`
- **User**: `pe-user` (password: `rhdh1234!`)

### Automated Configuration

The `update-keycloak-rhdh-config.sh` script handles SSO configuration:

1. Gets cluster routes for Keycloak and Developer Hub
2. Updates Keycloak realm import with correct redirect URIs
3. Updates Developer Hub ConfigMap with base URLs
4. Updates Developer Hub Secret with Keycloak URLs
5. Commits changes to Gitea
6. Triggers ArgoCD sync

### Manual Configuration

If automatic configuration fails:

```bash
# 1. Get routes
KEYCLOAK_ROUTE=$(oc get route keycloak-ingress -n keycloak -o jsonpath='{.spec.host}')
RHDH_ROUTE=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}')

# 2. Update Keycloak realm import in Gitea
# Edit: keycloak/manifests/05-realm-import-rhdh.yaml
# Set redirectUris to: https://${RHDH_ROUTE}/*

# 3. Update Developer Hub app-config in Gitea
# Edit: developerhub/manifests/04-app-config-configmap.yaml
# Set app.baseUrl to: https://${RHDH_ROUTE}

# 4. Update Developer Hub secrets in Gitea
# Edit: developerhub/manifests/06-secrets.yaml
# Set KEYCLOAK_BASE_URL to: https://${KEYCLOAK_ROUTE}

# 5. Sync applications in ArgoCD
oc patch application keycloak -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
oc patch application developer-hub -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

## Troubleshooting

### URLs are wrong in Gitea

If ArgoCD shows errors like "no such host gitea-gitea.apps.cluster-OLDCLUSTER...":

```bash
# Validate current URLs
cd assets/1_gitops
./validate-urls-before-push.sh

# Fix URLs and push to Gitea
./setup-gitops-repo.sh

# Or force update
./force-update-gitea.sh
```

### SSO redirect loop or "Invalid redirect URI"

```bash
cd assets/1_gitops
./update-keycloak-rhdh-config.sh
```

### Application stuck in "OutOfSync"

```bash
# Refresh and sync
oc patch application APP_NAME -n openshift-gitops --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"prune":true}}}'

# Or via ArgoCD CLI
argocd app sync APP_NAME
```

### Keycloak not starting

```bash
# Check Keycloak pod logs
oc logs -n keycloak -l app=keycloak

# Check PostgreSQL is running
oc get pods -n keycloak -l app.kubernetes.io/name=postgres

# Check database connection
oc describe keycloak keycloak -n keycloak
```

### Developer Hub can't connect to Keycloak

```bash
# Verify Keycloak route is accessible
oc get route keycloak-ingress -n keycloak
curl -k https://$(oc get route keycloak-ingress -n keycloak -o jsonpath='{.spec.host}')/realms/rhdh/.well-known/openid-configuration

# Check Developer Hub secrets
oc get secret rhdh-secrets -n rhdh -o jsonpath='{.data.KEYCLOAK_BASE_URL}' | base64 -d
```

## Testing & Validation

### Test URL Replacement Logic

```bash
cd assets/1_gitops/test
./test-url-replacement.sh
```

Shows before/after URL replacement without modifying real files.

### Validate URLs Before Push

```bash
cd assets/1_gitops
./validate-urls-before-push.sh
```

Checks that all ArgoCD application manifests have correct URLs.

### Debug URL Update Process

```bash
cd assets/1_gitops
./debug-url-update.sh
```

Shows detailed information about URL replacement process.

## Making Changes

### Update Application Manifests

1. Edit manifests in your local `assets/1_gitops/` directory
2. Run `setup-gitops-repo.sh` to push changes to Gitea
3. ArgoCD will automatically sync the changes

### Add New Application

1. Create manifests in new directory (e.g., `myapp/manifests/`)
2. Create ArgoCD Application manifest in `apps/XX-myapp.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: openshift-gitops
spec:
  project: default
  source:
    repoURL: GITEA_URL/admin/playground-gitops.git
    targetRevision: main
    path: myapp/manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

3. Run `setup-gitops-repo.sh` to push to Gitea
4. ArgoCD will discover and deploy the new application

## Documentation

- **Keycloak**: See [keycloak/README.md](keycloak/README.md)
  - RHSSO to RHBK migration
  - SSO configuration
  - Admin console access

- **Developer Hub**: See [developerhub/README.md](developerhub/README.md)
  - Installation methods
  - RBAC configuration
  - SSO integration

- **URL Fix Process**: See [URL_FIX_README.md](URL_FIX_README.md)
  - URL replacement logic
  - Validation scripts
  - Troubleshooting

- **Testing**: See [test/README.md](test/README.md)
  - Test framework usage
  - Validation tools

## Architecture

### App-of-Apps Pattern

```
playground-apps (Parent Application)
├── playground-namespaces
├── keycloak
├── developer-hub (with Keycloak SSO)
├── kafka-operator
├── devspaces
├── service-mesh
├── serverless
├── openshift-ai
├── amq-broker
├── elasticsearch
└── jaeger
```

### GitOps Workflow

```
Developer          GitHub              Local Cluster
    │                 │                      │
    │   1. Clone       │                      │
    │─────────────────>│                      │
    │                 │                      │
    │   2. Edit Files  │                      │
    │─────────X        │                      │
    │                 │                      │
    │   3. run_complete.sh                   │
    │────────────────────────────────────────>│
    │                 │         4. Deploy     │
    │                 │         ArgoCD/Gitea  │
    │                 │                      │
    │                 │    5. Create Gitea   │
    │                 │       playground-    │
    │                 │       gitops repo    │
    │                 │                      │
    │                 │    6. ArgoCD syncs   │
    │                 │       from Gitea     │
    │                 │                      │
    │   7. Access Apps                       │
    │<───────────────────────────────────────│
```

## Support

For detailed component documentation:
- [Keycloak README](keycloak/README.md)
- [Developer Hub README](developerhub/README.md)
- [URL Fix Documentation](URL_FIX_README.md)
- [Test Framework](test/README.md)

For issues:
- Check application logs: `oc logs -n NAMESPACE -l app=APPNAME`
- Review ArgoCD UI for sync status
- Validate URLs with `./validate-urls-before-push.sh`
- Run `./debug-url-update.sh` for detailed diagnostics
