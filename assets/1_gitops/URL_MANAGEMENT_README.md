# URL Management with ConfigMap

This document explains how cluster-specific URLs are managed using the `playground-config` ConfigMap.

## Overview

All cluster-specific URLs are now centrally managed through a ConfigMap created during the initial setup. This eliminates hardcoded URLs and makes the setup portable across different OpenShift clusters.

## Architecture

### 1. ConfigMap Creation (Initial Setup)

**When:** During `assets/0_initial_setup/install.sh` execution
**Where:** `openshift-gitops` namespace
**What:** Creates `playground-config` ConfigMap with `BASE_URL` property

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: playground-config
  namespace: openshift-gitops
data:
  BASE_URL: "apps.cluster-xxxxx.xxxxx.sandboxXXXX.opentlc.com"
```

The BASE_URL is automatically extracted from:
```bash
oc get ingresses.config/cluster -o jsonpath='{.spec.domain}'
```

### 2. URL Construction Pattern

All scripts construct URLs using this pattern:
```
https://<route-name>-<namespace>.<BASE_URL>
```

**Examples:**
- Gitea: `https://gitea-gitea.${BASE_URL}`
- ArgoCD: `https://openshift-gitops-server-openshift-gitops.${BASE_URL}`
- Keycloak: `https://keycloak-keycloak.${BASE_URL}`
- Developer Hub: `https://backstage-developer-hub-rhdh.${BASE_URL}`

### 3. Scripts Using ConfigMap

All GitOps scripts now read from the ConfigMap:

#### `setup-gitops-repo.sh`
- Reads BASE_URL from ConfigMap
- Constructs Gitea URL
- Updates ArgoCD Application manifests with correct repository URLs before pushing to Gitea

#### `update-keycloak-rhdh-config.sh` (NEW CAPABILITY)
- Reads BASE_URL from ConfigMap
- Constructs all service URLs
- **Clones the Gitea repository**
- **Updates ArgoCD Application repository URLs in all manifests**
- Updates Developer Hub secrets
- Updates Keycloak realm imports
- Updates OAuth client configurations
- Commits and pushes changes back to Gitea

#### `deploy-to-argocd.sh`
- Uses ConfigMap for URL construction in deployment scripts
- Falls back to querying routes if ConfigMap not found

#### `upload-and-deploy.sh`
- Uses ConfigMap for summary display

## Fixing Old/Incorrect URLs

### Problem
If the Gitea repository contains manifests with URLs from a different cluster, ArgoCD applications will point to the wrong repository.

### Solution
Run the update script to fix all URLs:

```bash
cd assets/1_gitops
./update-keycloak-rhdh-config.sh
```

This script will:
1. Read the BASE_URL from the ConfigMap
2. Clone the playground-gitops repository from Gitea
3. Find all ArgoCD Application manifests (`playground-apps.yaml`, `apps/*.yaml`)
4. Update all `repoURL` fields to match the current cluster's Gitea URL
5. Update all other cluster-specific configurations
6. Commit and push changes back to Gitea
7. Trigger ArgoCD sync for affected applications

### What Gets Updated

**ArgoCD Application Manifests:**
- `playground-apps.yaml` - Parent app-of-apps
- `apps/01-playground-namespaces.yaml`
- `apps/02-kafka-operator.yaml`
- `apps/03-developer-hub.yaml`
- `apps/04-devspaces.yaml`
- `apps/05-openshift-ai.yaml`
- `apps/06-service-mesh.yaml`
- `apps/07-serverless.yaml`
- `apps/08-amq-broker.yaml`
- `apps/09-elasticsearch.yaml`
- `apps/10-jaeger.yaml`
- `apps/11-keycloak.yaml`

**Pattern Matching:**
The script replaces any URL matching these patterns:
- `https://gitea-gitea.apps.cluster-xxxxx.xxxxx.sandboxXXXX.opentlc.com/admin/playground-gitops.git`
- `gitea-gitea.apps.cluster-xxxxx.xxxxx.sandboxXXXX.opentlc.com/admin/playground-gitops.git`

With the correct URL from the current cluster's ConfigMap.

**Other Configurations:**
- Developer Hub secrets (Keycloak URL, RHDH URL, OpenShift API URL)
- Keycloak realm import (RHDH redirect URIs)
- OpenShift OAuth client (RHDH redirect URIs)

## Verification

### Check ConfigMap
```bash
oc get configmap playground-config -n openshift-gitops -o yaml
```

### Check Constructed URLs
```bash
BASE_URL=$(oc get configmap playground-config -n openshift-gitops -o jsonpath='{.data.BASE_URL}')
echo "Gitea: https://gitea-gitea.${BASE_URL}"
echo "ArgoCD: https://openshift-gitops-server-openshift-gitops.${BASE_URL}"
echo "Keycloak: https://keycloak-keycloak.${BASE_URL}"
echo "RHDH: https://backstage-developer-hub-rhdh.${BASE_URL}"
```

### Verify Against Actual Routes
```bash
echo "Gitea (actual): $(oc get route gitea -n gitea -o jsonpath='{.spec.host}')"
echo "ArgoCD (actual): $(oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')"
```

### Check ArgoCD Apps in Gitea
1. Access Gitea: `https://gitea-gitea.${BASE_URL}/admin/playground-gitops`
2. Navigate to `apps/02-kafka-operator.yaml`
3. Verify the `repoURL` field matches your current cluster

## Troubleshooting

### ConfigMap Not Found
```
Error: Could not find playground-config ConfigMap
```

**Solution:** Run the initial setup:
```bash
cd assets/0_initial_setup
./install.sh
```

### Wrong URLs in Gitea Repository
```
ArgoCD apps showing "ComparisonError" or pointing to wrong cluster
```

**Solution:** Run the update script:
```bash
cd assets/1_gitops
./update-keycloak-rhdh-config.sh
```

### Git Authentication Failed
```
Failed to clone repository / Failed to push changes to Gitea
```

**Solution:** Configure git credentials:
```bash
git config --global credential.helper store
# Or use SSH keys
```

## Migration from Old Setup

If you have an existing setup with hardcoded URLs:

1. **Create the ConfigMap** (if not exists):
   ```bash
   CLUSTER_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
   cat <<EOF | oc apply -f -
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: playground-config
     namespace: openshift-gitops
   data:
     BASE_URL: "${CLUSTER_DOMAIN}"
   EOF
   ```

2. **Run the update script**:
   ```bash
   cd assets/1_gitops
   ./update-keycloak-rhdh-config.sh
   ```

3. **Verify ArgoCD applications**:
   ```bash
   oc get applications -n openshift-gitops
   ```

4. **Check application sync status**:
   - Access ArgoCD UI
   - Verify all apps are synced
   - Check that repository URLs are correct

## Benefits

1. **Portability:** Setup works on any OpenShift cluster without manual URL updates
2. **Consistency:** All URLs follow the same construction pattern
3. **Maintainability:** Single source of truth for cluster domain
4. **Automation:** Scripts automatically use correct URLs from ConfigMap
5. **Recovery:** Easy to fix incorrect URLs with update script
