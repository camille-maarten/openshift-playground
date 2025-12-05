# ConfigMap-Based URL Management - Integration Complete

## Summary

The GitOps manifests have been successfully refactored to use a centralized ConfigMap for managing cluster-specific URLs. The URL update process is now **automatically integrated** into the deployment workflow.

## What Changed

### 1. Initial Setup (0_initial_setup)

**New ConfigMap Template:**
- `manifests/11-playground-config-configmap.yaml` - Template for the playground-config ConfigMap

**Updated Script:**
- `install.sh` - Now creates the `playground-config` ConfigMap with the cluster's BASE_URL after ArgoCD installation

```bash
# Automatically extracts and stores cluster domain
CLUSTER_DOMAIN=$(oc get ingresses.config/cluster -o jsonpath='{.spec.domain}')
# Creates ConfigMap in openshift-gitops namespace
```

### 2. GitOps Scripts (1_gitops)

**Enhanced Scripts:**

All scripts now read `BASE_URL` from the ConfigMap instead of querying routes individually:

- ✅ `setup-gitops-repo.sh` - Uses ConfigMap for Gitea URL construction
- ✅ `update-keycloak-rhdh-config.sh` - **Enhanced** to also update ArgoCD Application repository URLs
- ✅ `deploy-to-argocd.sh` - Uses ConfigMap for all URLs with fallback, **now calls update script automatically**
- ✅ `upload-and-deploy.sh` - Uses ConfigMap for summary, **now calls update script automatically**
- ✅ `run_complete.sh` - Updated to reflect integrated URL updates

### 3. Automatic URL Updates

**New Workflow Integration:**

The `update-keycloak-rhdh-config.sh` script is now automatically called during deployment:

```
1. upload-and-deploy.sh
   ├─ setup-gitops-repo.sh (uploads manifests to Gitea)
   ├─ deploy-to-argocd.sh (creates ArgoCD apps)
   └─ update-keycloak-rhdh-config.sh ⭐ NEW: Automatically fixes all URLs

2. deploy-to-argocd.sh (standalone)
   ├─ create_playground_app_of_apps (creates apps)
   ├─ sync_applications (syncs apps)
   └─ update_cluster_urls ⭐ NEW: Calls update script

3. run_complete.sh
   ├─ run_initial_setup
   └─ run_gitops_deployment (includes URL update)
```

## What Gets Updated Automatically

When you run `upload-and-deploy.sh` or `deploy-to-argocd.sh`, the system now automatically:

1. **Reads BASE_URL from ConfigMap**
   ```bash
   BASE_URL=$(oc get configmap playground-config -n openshift-gitops -o jsonpath='{.data.BASE_URL}')
   ```

2. **Constructs Service URLs**
   - Gitea: `https://gitea-gitea.${BASE_URL}`
   - ArgoCD: `https://openshift-gitops-server-openshift-gitops.${BASE_URL}`
   - Keycloak: `https://keycloak-keycloak.${BASE_URL}`
   - Developer Hub: `https://backstage-developer-hub-rhdh.${BASE_URL}`

3. **Updates Manifests in Gitea Repository**
   - All ArgoCD Application `repoURL` fields (12 files)
   - Developer Hub secrets (Keycloak, RHDH, OpenShift API URLs)
   - Keycloak realm import (RHDH redirect URIs)
   - OpenShift OAuth client (RHDH redirect URIs)

4. **Commits and Pushes to Gitea**
   ```
   Update ArgoCD apps, Keycloak and RHDH configuration with cluster routes from ConfigMap
   ```

5. **Triggers ArgoCD Sync**
   - ArgoCD automatically picks up the changes and resyncs applications

## Usage

### Fresh Installation

```bash
# 1. Run initial setup (creates ConfigMap)
cd assets/0_initial_setup
./install.sh

# 2. Deploy GitOps (automatically updates URLs)
cd ../1_gitops
./upload-and-deploy.sh
```

The ConfigMap is created in step 1, and URLs are automatically updated in step 2. **No manual intervention needed!**

### Existing Installation with Wrong URLs

If your Gitea repository has URLs from a different cluster:

**Option A: Run the complete workflow**
```bash
cd assets/1_gitops
./upload-and-deploy.sh
# URLs are automatically updated during deployment
```

**Option B: Run the update script manually**
```bash
cd assets/1_gitops
./update-keycloak-rhdh-config.sh
# Standalone execution to fix URLs
```

### Verification

**Check ConfigMap:**
```bash
oc get configmap playground-config -n openshift-gitops -o yaml
```

**Verify URLs in Gitea:**
1. Access Gitea UI: `https://gitea-gitea.<BASE_URL>/admin/playground-gitops`
2. Check `apps/02-kafka-operator.yaml`
3. Verify `repoURL` matches your current cluster

**Check ArgoCD Applications:**
```bash
# List applications
oc get applications -n openshift-gitops

# Check specific app source
oc get application kafka-operator -n openshift-gitops -o jsonpath='{.spec.source.repoURL}'
```

## Benefits

### Before (Manual URL Management)
- ❌ URLs hardcoded in manifests
- ❌ Manual updates needed when changing clusters
- ❌ Prone to errors and inconsistencies
- ❌ Multiple scripts querying routes individually
- ❌ Manual script execution required

### After (ConfigMap-Based + Automatic Updates)
- ✅ Single source of truth (ConfigMap)
- ✅ Automatic URL updates during deployment
- ✅ Portable across clusters (zero manual updates)
- ✅ Consistent URL construction pattern
- ✅ Automatic Gitea repository updates
- ✅ Self-healing: runs on every deployment

## Troubleshooting

### ConfigMap Not Found
```
Error: Could not find playground-config ConfigMap
```

**Solution:** Run initial setup:
```bash
cd assets/0_initial_setup
./install.sh
```

### URLs Still Wrong in Gitea

**Check if update script ran:**
```bash
# Check last commit in Gitea
cd /tmp
git clone https://gitea-gitea.<BASE_URL>/admin/playground-gitops.git
cd playground-gitops
git log -1
# Should see: "Update ArgoCD apps, Keycloak and RHDH configuration..."
```

**Re-run update manually:**
```bash
cd assets/1_gitops
./update-keycloak-rhdh-config.sh
```

### Git Authentication Failed

The update script needs to clone and push to Gitea:

```bash
# Configure git credential helper
git config --global credential.helper store

# Or use URL with embedded credentials (less secure)
# The script already handles this for Gitea
```

## Files Modified

### Initial Setup
- ✏️ `assets/0_initial_setup/install.sh` (+28 lines)
- ➕ `assets/0_initial_setup/manifests/11-playground-config-configmap.yaml` (new)

### GitOps Scripts
- ✏️ `assets/1_gitops/setup-gitops-repo.sh` (ConfigMap integration)
- ✏️ `assets/1_gitops/update-keycloak-rhdh-config.sh` (+ArgoCD app URL updates)
- ✏️ `assets/1_gitops/deploy-to-argocd.sh` (+automatic update call)
- ✏️ `assets/1_gitops/upload-and-deploy.sh` (+automatic update call)
- ✏️ `assets/1_gitops/run_complete.sh` (streamlined workflow)

### Documentation
- ➕ `assets/1_gitops/URL_MANAGEMENT_README.md` (comprehensive guide)
- ➕ `CONFIGMAP_URL_INTEGRATION.md` (this file)

## Testing

### Test ConfigMap Creation
```bash
cd assets/0_initial_setup
# (Assuming OpenShift login is already done)

# Check current cluster domain
oc get ingresses.config/cluster -o jsonpath='{.spec.domain}'

# Verify ConfigMap (if already created)
oc get configmap playground-config -n openshift-gitops -o yaml
```

### Test URL Construction
```bash
BASE_URL=$(oc get configmap playground-config -n openshift-gitops -o jsonpath='{.data.BASE_URL}')

# Constructed URLs
echo "Gitea:         https://gitea-gitea.${BASE_URL}"
echo "ArgoCD:        https://openshift-gitops-server-openshift-gitops.${BASE_URL}"
echo "Keycloak:      https://keycloak-keycloak.${BASE_URL}"
echo "Developer Hub: https://backstage-developer-hub-rhdh.${BASE_URL}"

# Actual routes (for comparison)
echo ""
echo "Actual Gitea route: $(oc get route gitea -n gitea -o jsonpath='{.spec.host}' 2>/dev/null || echo 'N/A')"
```

### Test Automatic Update
```bash
cd assets/1_gitops

# Run deployment (includes automatic URL update)
./upload-and-deploy.sh

# Check Gitea repository for correct URLs
# Access: https://gitea-gitea.<BASE_URL>/admin/playground-gitops
# Navigate to: apps/02-kafka-operator.yaml
# Verify: repoURL matches current cluster
```

## Migration Path

For existing deployments with hardcoded URLs:

1. **Create ConfigMap** (if not exists):
   ```bash
   cd assets/0_initial_setup
   ./install.sh  # Or run just the ConfigMap creation section
   ```

2. **Run deployment script** (automatic update):
   ```bash
   cd ../1_gitops
   ./upload-and-deploy.sh
   ```

3. **Verify** ArgoCD applications are synced:
   ```bash
   oc get applications -n openshift-gitops
   ```

## Next Steps

1. ✅ ConfigMap created during initial setup
2. ✅ All scripts use ConfigMap for URL construction
3. ✅ Automatic URL updates integrated into deployment
4. ✅ Documentation created

**Future Enhancements:**
- Consider using ArgoCD's built-in variable substitution
- Add URL validation before updates
- Create a health check script to verify all URLs are correct
- Add support for custom domain configurations

## References

- [URL Management README](assets/1_gitops/URL_MANAGEMENT_README.md) - Detailed technical documentation
- [OpenShift GitOps Documentation](https://docs.openshift.com/container-platform/latest/cicd/gitops/)
- [ArgoCD Application Specification](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
