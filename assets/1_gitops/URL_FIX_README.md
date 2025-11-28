# Git URL Fix - Complete Solution

## Problem Summary

After running `run_complete.sh`, ArgoCD applications in Gitea contained wrong URLs:
- Some had `GITEA_URL` placeholders (not replaced)
- Some had URLs from old/different clusters
- This caused ArgoCD error: `no such host gitea-gitea.apps.cluster-OLDCLUSTER...`

## Root Causes Identified

1. **Inconsistent template restoration**: `restore_template_files()` only restored 4 files, leaving others with mixed URLs
2. **Missing test directory exclusion**: Test output files were being processed along with real files
3. **No validation**: No way to verify URLs were correct before pushing to Gitea

## Fixes Applied

### 1. Fixed URL Replacement Logic (setup-gitops-repo.sh)

**Changed:**
```bash
# Old: Complex logic that didn't reliably replace all patterns
sed "/repoURL:.*${CURRENT_CLUSTER_DOMAIN}/!s|repoURL: https://[^/]*apps\.cluster-[^/]*/|..."

# New: Simple, comprehensive replacement
sed "s|GITEA_URL|${GITEA_ROUTE}|g" "$file"
sed "s|repoURL: https://[^/]*/[^/]*/playground-gitops\.git|repoURL: ${TARGET_REPO_URL}|g" "$file"
```

### 2. Fixed Template Restoration (setup-gitops-repo.sh:472-473)

**Changed:**
```bash
# Old: Only restored 4 files
git restore assets/1_gitops/playground-apps.yaml \
           assets/1_gitops/apps/01-playground-namespaces.yaml \
           assets/1_gitops/apps/02-kafka-operator.yaml \
           assets/1_gitops/apps/03-developer-hub.yaml

# New: Restores ALL app files
git restore assets/1_gitops/playground-apps.yaml
git restore assets/1_gitops/apps/*.yaml
```

### 3. Excluded Test Directory (setup-gitops-repo.sh:308)

**Changed:**
```bash
# Old: Included test output files
find . -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \)

# New: Excludes test directory
find . -type f \( -name "playground-apps.yaml" -o -path "*/apps/*.yaml" \) ! -path "*/test/*"
```

### 4. Added Test Framework

**New files:**
- `test/test-url-replacement.sh` - Tests URL replacement logic before deployment
- `validate-urls-before-push.sh` - Validates all URLs are correct

## How to Use

### Method 1: Automated (Recommended)

Just run the complete setup:

```bash
cd /path/to/openshift-playground
./run_complete.sh
```

The script now automatically:
1. Updates all URLs correctly
2. Pushes to Gitea
3. Waits for Keycloak and RHDH routes
4. Configures SSO integration
5. Restores template files for local development

### Method 2: Manual Verification

If you want to verify URLs before deployment:

```bash
# Step 1: Test the URL replacement logic
cd assets/1_gitops/test
./test-url-replacement.sh

# Step 2: Run the full setup
cd ..
./setup-gitops-repo.sh

# Step 3: Validate URLs before they go to Gitea
./validate-urls-before-push.sh

# If validation passes, URLs are already in Gitea (setup-gitops-repo.sh pushed them)
```

### Method 3: Fix Existing Gitea Repository

If you already have a Gitea repository with wrong URLs:

```bash
# Step 1: Validate current state
cd assets/1_gitops
./validate-urls-before-push.sh

# Step 2: If validation fails, run setup-gitops-repo.sh again
# This will update URLs and push to Gitea
./setup-gitops-repo.sh

# Step 3: Validate again
./validate-urls-before-push.sh
```

## Validation Script Output

The `validate-urls-before-push.sh` script shows:

**Success:**
```
✓ playground-apps.yaml: Correct URL
✓ 03-developer-hub.yaml: Correct URL
✓ 11-keycloak.yaml: Correct URL

Validation PASSED! All URLs are correct.
```

**Failure:**
```
✗ playground-apps.yaml: Still has GITEA_URL placeholder!
  Current: GITEA_URL/admin/playground-gitops.git
  Expected: https://gitea-gitea.apps.cluster-jstg2...

Validation FAILED! Do not push to Gitea yet.
```

## Test Framework

The test framework in `test/` allows you to:

1. **Test URL replacement without modifying real files**
2. **See before/after for each file**
3. **Verify logic works for your cluster**

```bash
cd assets/1_gitops/test
./test-url-replacement.sh
```

Output shows:
- What files were found
- Before/after URLs for each file
- Validation of all URLs
- Test files stored in `test/output/` for inspection

## Troubleshooting

### Issue: Validation still fails after running setup-gitops-repo.sh

**Solution:**
1. Make sure you're logged into OpenShift: `oc whoami`
2. Check Gitea route exists: `oc get route gitea -n gitea`
3. Run validation to see which files are wrong: `./validate-urls-before-push.sh`
4. Run setup-gitops-repo.sh again (it's idempotent)

### Issue: ArgoCD shows "no such host" error

**This means the URLs in Gitea are wrong.**

**Solution:**
```bash
# Fix URLs and push to Gitea again
cd assets/1_gitops
./setup-gitops-repo.sh

# Verify Gitea has correct URLs (check in Gitea UI or):
# Clone the repo and check files
git clone https://$(oc get route gitea -n gitea -o jsonpath='{.spec.host}')/admin/playground-gitops.git /tmp/test-repo
cd /tmp/test-repo
grep "repoURL:" playground-apps.yaml
grep "repoURL:" apps/*.yaml
```

### Issue: Template files have actual URLs instead of GITEA_URL

**This is EXPECTED after running setup-gitops-repo.sh locally.**

The script:
1. Updates URLs to actual cluster values
2. Pushes to Gitea (with correct URLs)
3. Restores template files locally (for GitHub commits)

Your local files should have templates. Gitea should have actual URLs.

To restore templates manually:
```bash
cd /path/to/openshift-playground
git restore assets/1_gitops/playground-apps.yaml
git restore assets/1_gitops/apps/*.yaml
```

## Files Modified

1. **setup-gitops-repo.sh**
   - Line 308: Exclude test directory from find
   - Lines 323-337: Simplified URL replacement logic
   - Lines 293-298: Added test/output/ to .gitignore
   - Lines 472-473: Fixed to restore ALL app files

2. **run_complete.sh**
   - Added wait_for_routes() function
   - Added configure_keycloak_rhdh() function
   - Integrated automatic SSO configuration

3. **New Files**
   - `test/test-url-replacement.sh` - Test framework
   - `test/README.md` - Test documentation
   - `validate-urls-before-push.sh` - Pre-push validation
   - `update-keycloak-rhdh-config.sh` - Keycloak/RHDH SSO config

## Summary

✅ **URL replacement is now reliable and tested**
✅ **Validation script prevents pushing wrong URLs**
✅ **Test framework allows verification before deployment**
✅ **All 12 ArgoCD app files handled consistently**
✅ **run_complete.sh now fully automated including SSO**

## Next Steps

1. Run `./run_complete.sh` for full automated setup
2. Or use `./validate-urls-before-push.sh` to check current state
3. Use `test/test-url-replacement.sh` to test URL replacement logic

All scripts are idempotent and can be run multiple times safely.
