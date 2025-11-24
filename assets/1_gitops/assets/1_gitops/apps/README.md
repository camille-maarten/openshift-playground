# ArgoCD Applications

This directory contains ArgoCD Application definitions for the platform components.

## App of Apps Pattern

This uses the "app of apps" pattern where a parent Application (`playground-apps`)
manages these child applications. All changes to platform components should be made
through these YAML files and pushed to Gitea.

## Applications

1. **01-playground-namespaces.yaml** - Playground namespace with resource quotas and policies
2. **02-kafka-operator.yaml** - AMQ Streams (Kafka) operator installation
3. **03-developer-hub.yaml** - Red Hat Developer Hub installation

## How It Works

1. The `playground-apps` Application in ArgoCD monitors this `apps/` directory in Gitea
2. When you push changes to these files in Gitea, ArgoCD automatically syncs the child applications
3. Each child application then manages its respective manifests in the `manifests/` directories

## Making Changes

To modify platform components:

1. Edit the appropriate application YAML file in this directory
2. Commit and push changes to Gitea
3. ArgoCD will automatically detect and sync the changes

Example:
```bash
# Edit an application definition
vim assets/1_gitops/apps/03-developer-hub.yaml

# Commit and push to Gitea
git add assets/1_gitops/apps/03-developer-hub.yaml
git commit -m "Update Developer Hub sync policy"
git push
```

## Application Structure

Each application YAML defines:
- `metadata.name`: Unique name for the application
- `spec.source.repoURL`: Git repository URL (Gitea)
- `spec.source.path`: Path to manifests directory
- `spec.destination`: Target cluster and namespace
- `spec.syncPolicy`: How ArgoCD should sync resources

## Notes

- These files are templates with `GITEA_URL` placeholder
- The deployment script replaces `GITEA_URL` with the actual cluster Gitea route
- All applications use automated sync with prune and self-heal enabled
