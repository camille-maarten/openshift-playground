# URL Replacement Test

This directory contains a test script to validate the URL replacement logic before deploying to ArgoCD.

## Purpose

The `test-url-replacement.sh` script:
1. Gets the actual Gitea route from your OpenShift cluster
2. Creates test template files with various URL patterns (placeholders, old cluster URLs, etc.)
3. Applies the same URL replacement logic used in `setup-gitops-repo.sh`
4. Validates that all URLs are correctly updated
5. Stores the results in `output/` for inspection

## Usage

```bash
# Make sure you're logged into OpenShift
oc login

# Run the test
cd assets/1_gitops/test
./test-url-replacement.sh
```

## Test Scenarios

The test validates these scenarios:

1. **Placeholder Replacement**: `GITEA_URL` → actual Gitea route
2. **Old Cluster URLs**: URLs from previous cluster deployments are updated to current cluster
3. **Consistency**: All ArgoCD Application manifests get the same, correct repoURL

## Expected Output

When successful, you'll see:
```
✓ playground-apps.yaml: Correct URL
✓ 03-developer-hub.yaml: Correct URL
✓ 11-keycloak.yaml: Correct URL
✓ 02-kafka-operator.yaml: Correct URL

All URLs are correct! ✓
```

## Inspecting Results

The processed files are stored in `output/`:
```bash
cd output
cat playground-apps.yaml       # Check parent app
cat apps/03-developer-hub.yaml  # Check child apps
```

All `repoURL` fields should point to:
```
https://<gitea-route>/admin/playground-gitops.git
```

## Troubleshooting

If the test fails:
1. Check that you're logged into OpenShift: `oc whoami`
2. Check that Gitea is deployed: `oc get route gitea -n gitea`
3. Review the BEFORE/AFTER output to see what changed
4. Inspect files in `output/` to see the actual results

## Integration

This test validates the logic in:
- `../setup-gitops-repo.sh` (function: `update_argocd_repo_urls`)

Before modifying URL replacement logic, run this test to ensure it still works correctly.
