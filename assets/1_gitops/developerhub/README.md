# Red Hat Developer Hub Installation

This directory contains the manifests to install Red Hat Developer Hub (RHDH) on OpenShift using the RHDH Operator.

## Overview

Red Hat Developer Hub is an enterprise-grade internal developer portal based on Backstage. This installation includes:

- **RHDH Operator**: Manages the Developer Hub instance
- **PostgreSQL Database**: Persistent storage for catalog and user data
- **Dynamic Plugin Caching**: Enabled for improved performance
- **RBAC Configuration**: Role-based access control with 5 distinct personas
- **OpenShift Groups**: Pre-configured for easy user assignment

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Red Hat Developer Hub                     │
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   Frontend   │───▶│   Backend    │───▶│  PostgreSQL  │   │
│  │  (Backstage) │    │   (Node.js)  │    │   Database   │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│         │                    │                               │
│         │                    │                               │
│         ▼                    ▼                               │
│  ┌──────────────────────────────────────────────┐            │
│  │        Dynamic Plugins (with caching)        │            │
│  └──────────────────────────────────────────────┘            │
│                                                               │
│  ┌──────────────────────────────────────────────┐            │
│  │         RBAC Policy & Permissions            │            │
│  └──────────────────────────────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

## Personas and RBAC

The installation creates 5 distinct personas, each with their own OpenShift group for easy permission management:

### 1. Platform Admin (`role:platform-admin`)
- **Group**: `rhdh-platform-admins`
- **Permissions**: Full administrative access to all resources
- **Use Case**: Infrastructure and platform team members

### 2. Technical Lead (`role:technical-lead`)
- **Group**: `rhdh-technical-leads`
- **Permissions**: Full access (currently admin-level, can be customized)
- **Use Case**: Team leads, architects, senior developers

### 3. Developer (`role:developer`)
- **Group**: `rhdh-developers`
- **Permissions**: Full access (currently admin-level, can be customized)
- **Use Case**: Software developers

### 4. Tester (`role:tester`)
- **Group**: `rhdh-testers`
- **Permissions**: Full access (currently admin-level, can be customized)
- **Use Case**: QA engineers, testers

### 5. Product Owner (`role:product-owner`)
- **Group**: `rhdh-product-owners`
- **Permissions**: Full access (currently admin-level, can be customized)
- **Use Case**: Product managers, stakeholders

**Note**: All roles currently have admin-level permissions to ensure everything works. You can easily customize permissions by editing `05-rbac-policy-configmap.yaml`.

## Installation

### Prerequisites

- OpenShift cluster with cluster-admin access
- OpenShift GitOps (ArgoCD) installed and configured
- Git repository containing these manifests
- Red Hat Developer Hub Operator available in OperatorHub

### Installation Methods

You can install Developer Hub using either ArgoCD (recommended for GitOps) or manual kubectl/oc commands.

#### Method 1: ArgoCD Installation (Recommended)

This is the GitOps approach and is the recommended method.

1. **Push manifests to your Git repository**:

```bash
# Ensure all manifests are committed to your Git repository
git add assets/1_gitops/developerhub/
git commit -m "Add Developer Hub manifests"
git push
```

2. **Update the ArgoCD Application manifest**:

Edit `argocd-application.yaml` and update the `repoURL` to point to your Git repository:

```yaml
source:
  repoURL: https://github.com/YOUR_ORG/YOUR_REPO.git  # Change this
  targetRevision: main
  path: assets/1_gitops/developerhub/manifests
```

3. **Apply the ArgoCD Application**:

```bash
oc apply -f assets/1_gitops/developerhub/argocd-application.yaml
```

4. **Monitor the deployment in ArgoCD**:

```bash
# Via CLI
argocd app get developer-hub
argocd app sync developer-hub

# Via UI - Access ArgoCD web interface
oc get route openshift-gitops-server -n openshift-gitops
```

ArgoCD will automatically:
- Create the namespace
- Install the operator
- Deploy PostgreSQL
- Configure RBAC
- Create the Backstage instance
- Handle the correct deployment order
- Auto-sync any future changes from Git

#### Method 2: Manual Installation

If you prefer to install manually without ArgoCD:

1. **Apply all manifests in order**:

```bash
cd assets/1_gitops/developerhub/manifests

# Create namespace and install operator
oc apply -f 01-namespace.yaml
oc apply -f 02-operatorgroup.yaml
oc apply -f 03-subscription.yaml

# Wait for operator to be ready
oc wait --for=condition=Ready pod -l control-plane=controller-manager -n rhdh --timeout=300s

# Create configuration and resources
oc apply -f 04-app-config-configmap.yaml
oc apply -f 05-rbac-policy-configmap.yaml
oc apply -f 06-secrets.yaml
oc apply -f 07-postgres-deployment.yaml
oc apply -f 09-dynamic-plugins-configmap.yaml
oc apply -f 10-rbac-groups.yaml

# Wait for PostgreSQL to be ready
oc wait --for=condition=Ready pod -l app.kubernetes.io/name=postgres -n rhdh --timeout=300s

# Create the Backstage instance
oc apply -f 08-backstage-instance.yaml
```

2. **Wait for Developer Hub to be ready**:

```bash
oc get backstage -n rhdh -w
```

3. **Get the route URL**:

```bash
oc get route -n rhdh
```

## Configuration

### Database Configuration

The PostgreSQL database is deployed with:
- **Storage**: 5Gi PersistentVolume
- **User**: postgres
- **Password**: rhdh1234! (change in `06-secrets.yaml`)
- **Database**: backstage

### Dynamic Plugins

Dynamic plugin caching is enabled with:
- **Cache TTL**: 24 hours (86400 seconds)
- **Cache Store**: Memory
- **Max Items**: 500
- **Enabled Plugins**: Kubernetes, TechDocs

To modify plugin configuration, edit `09-dynamic-plugins-configmap.yaml`.

### RBAC Customization

To customize permissions for each role:

1. Edit `05-rbac-policy-configmap.yaml`
2. Modify the permission policies under each role section
3. Apply the changes:
   ```bash
   oc apply -f 05-rbac-policy-configmap.yaml
   oc rollout restart deployment/backstage-developer-hub -n rhdh
   ```

Example permission formats:
```yaml
# Allow read access to catalog entities
p, role:developer, catalog.entity.read, *, allow

# Deny delete access to catalog entities
p, role:developer, catalog.entity.delete, *, deny

# Allow execution of scaffolder templates
p, role:developer, scaffolder.action.execute, *, allow
```

## User Management

### Adding Users to Groups

To assign users to the RBAC groups:

```bash
# Add user to platform-admins group
oc adm groups add-users rhdh-platform-admins <username>

# Add user to developers group
oc adm groups add-users rhdh-developers <username>

# Add user to technical-leads group
oc adm groups add-users rhdh-technical-leads <username>

# Add user to testers group
oc adm groups add-users rhdh-testers <username>

# Add user to product-owners group
oc adm groups add-users rhdh-product-owners <username>
```

### Listing Group Members

```bash
# View all groups
oc get groups | grep rhdh

# View specific group details
oc get group rhdh-developers -o yaml
```

## Accessing Developer Hub

1. Get the route URL:
   ```bash
   RHDH_URL=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}')
   echo "https://${RHDH_URL}"
   ```

2. Access Developer Hub in your browser

3. Log in using OpenShift OAuth (click "Log in via OpenShift")

## Troubleshooting

### Check Operator Status

```bash
oc get csv -n rhdh
oc get pods -n rhdh
```

### Check Backstage Instance Status

```bash
oc get backstage -n rhdh
oc describe backstage developer-hub -n rhdh
```

### View Logs

```bash
# Backstage pod logs
oc logs -f deployment/backstage-developer-hub -n rhdh

# PostgreSQL pod logs
oc logs -f deployment/postgres-rhdh -n rhdh

# Operator logs
oc logs -f deployment/rhdh-operator-controller-manager -n rhdh
```

### Common Issues

1. **Database Connection Failed**
   - Verify PostgreSQL is running: `oc get pods -n rhdh`
   - Check database credentials in secrets: `oc get secret rhdh-secrets -n rhdh -o yaml`

2. **Plugin Loading Issues**
   - Check dynamic plugins ConfigMap: `oc get cm dynamic-plugins-rhdh -n rhdh -o yaml`
   - Review Backstage logs for plugin errors

3. **RBAC Permission Denied**
   - Verify user is in correct group: `oc get groups`
   - Check RBAC policy: `oc get cm rbac-policy -n rhdh -o yaml`

## Uninstallation

### Using ArgoCD

If you installed via ArgoCD:

```bash
# Delete the ArgoCD Application (this will remove all resources)
oc delete application developer-hub -n openshift-gitops

# Optionally, also delete the namespace and groups
oc delete namespace rhdh
oc delete group rhdh-platform-admins rhdh-technical-leads rhdh-developers rhdh-testers rhdh-product-owners
```

### Manual Uninstallation

If you installed manually:

```bash
# Delete Backstage instance
oc delete backstage developer-hub -n rhdh

# Delete all resources
oc delete -f manifests/

# Delete namespace (this will remove everything)
oc delete namespace rhdh

# Delete OpenShift groups
oc delete group rhdh-platform-admins rhdh-technical-leads rhdh-developers rhdh-testers rhdh-product-owners
```

## Next Steps

1. **Configure Catalog Locations**: Add your GitHub/GitLab repositories to the catalog
2. **Customize Permissions**: Edit RBAC policies for each persona based on your needs
3. **Add Software Templates**: Create scaffolder templates for your organization
4. **Enable Additional Plugins**: Configure more dynamic plugins as needed
5. **Configure Integrations**: Set up GitHub, GitLab, Kubernetes, and other integrations

## References

- [Red Hat Developer Hub Documentation](https://access.redhat.com/documentation/en-us/red_hat_developer_hub)
- [Backstage Documentation](https://backstage.io/docs/overview/what-is-backstage)
- [RHDH Operator GitHub](https://github.com/janus-idp/operator)
