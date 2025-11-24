# Red Hat OpenShift Dev Spaces

Cloud-based development environment that provides browser-based IDEs for developers.

## Overview

Red Hat OpenShift Dev Spaces (formerly Red Hat CodeReady Workspaces) is a collaborative Kubernetes-native development platform that delivers consistent developer environments on Red Hat OpenShift. It provides zero-config, ready-to-code developer workspaces in a browser.

## Components

This GitOps configuration deploys:

1. **Dev Spaces Operator** - Manages the lifecycle of Dev Spaces infrastructure
2. **CheCluster Instance** - The actual Dev Spaces deployment with configured settings

## Manifests

### 01-namespace.yaml
Creates the `openshift-devspaces` namespace where the operator and workspaces will be deployed.

### 02-operatorgroup.yaml
Configures the OperatorGroup for the Dev Spaces operator, scoping it to the `openshift-devspaces` namespace.

### 03-subscription.yaml
Subscribes to the `devspaces` operator from the Red Hat Operators catalog (stable channel).

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Source: `redhat-operators`

### 04-checluster.yaml
Defines the Dev Spaces instance with the following configuration:

**Features:**
- **Metrics**: Enabled for monitoring
- **VS Code Support**: Uses che-incubator/che-code as default editor
- **Open VSX Integration**: Connected to https://open-vsx.org for extensions
- **Auto-provisioning**: Automatically creates namespaces for users
- **Unlimited Workspaces**: No limit on workspaces per user (`maxNumberOfWorkspacesPerUser: -1`)
- **No Idle Timeout**: Workspaces don't idle automatically (`secondsOfRunBeforeIdling: -1`)
- **Container Build**: Supports building containers within workspaces

**Namespace Template:**
- User workspaces created as: `<username>-devspaces`

## Deployment

### Via GitOps (Recommended)

The ArgoCD Application is defined in `apps/04-devspaces.yaml` and will be automatically deployed when using the App-of-Apps pattern.

```bash
# Upload manifests and deploy
cd assets/1_gitops
./upload-and-deploy.sh
```

### Manual Deployment

```bash
# Apply manifests directly
oc apply -f devspaces/manifests/

# Or via ArgoCD
oc apply -f apps/04-devspaces.yaml
```

## Access

Once deployed, access Dev Spaces through:

1. **Get the route:**
   ```bash
   oc get route devspaces -n openshift-devspaces
   ```

2. **Open in browser:**
   ```bash
   echo "https://$(oc get route devspaces -n openshift-devspaces -o jsonpath='{.spec.host}')"
   ```

3. **Login** using your OpenShift credentials

## Features

### Browser-Based IDE
- Full-featured VS Code experience in the browser
- No local installation required
- Access from anywhere

### Developer Workspaces
- Pre-configured development environments
- Consistent tooling across teams
- Support for devfile.io specifications

### Extension Support
- Open VSX registry integration
- Install extensions directly in workspaces
- Custom plugin support

### Container Development
- Build and run containers within workspaces
- Direct Kubernetes/OpenShift integration
- Built-in terminal access

## Verification

Check deployment status:

```bash
# Check operator
oc get csv -n openshift-devspaces | grep devspaces

# Check CheCluster status
oc get checluster devspaces -n openshift-devspaces

# Check pods
oc get pods -n openshift-devspaces

# Check route
oc get route -n openshift-devspaces
```

## Configuration

### User Namespace Pattern

By default, user workspaces are created in namespaces following the pattern: `<username>-devspaces`

Modify in `04-checluster.yaml`:
```yaml
spec:
  devEnvironments:
    defaultNamespace:
      template: <username>-devspaces
```

### Workspace Limits

Current configuration allows unlimited workspaces. To set limits:

```yaml
spec:
  devEnvironments:
    maxNumberOfWorkspacesPerUser: 5  # Limit to 5 workspaces per user
```

### Idle Timeout

To enable workspace idling after inactivity:

```yaml
spec:
  devEnvironments:
    secondsOfRunBeforeIdling: 1800  # Idle after 30 minutes
```

## Troubleshooting

### Pods Not Starting

```bash
# Check operator logs
oc logs -n openshift-devspaces -l app.kubernetes.io/component=devspaces-operator

# Check events
oc get events -n openshift-devspaces --sort-by='.lastTimestamp'
```

### Workspace Issues

```bash
# List user namespaces
oc get namespaces | grep devspaces

# Check workspace pods
oc get pods -n <username>-devspaces

# Check workspace logs
oc logs -n <username>-devspaces <pod-name>
```

### Cannot Access Route

```bash
# Verify route exists
oc get route devspaces -n openshift-devspaces

# Check ingress
oc describe route devspaces -n openshift-devspaces
```

## Resources

- [Red Hat OpenShift Dev Spaces Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_dev_spaces/)
- [Eclipse Che (upstream project)](https://www.eclipse.org/che/)
- [Devfile.io](https://devfile.io/)

## Notes

- **Sync Wave**: CheCluster instance uses sync wave 10 to ensure operator is ready before creating the instance
- **GitOps Friendly**: Ignores status and metrics fields to prevent sync issues
- **Resource Requirements**: Dev Spaces requires significant cluster resources, especially for multiple concurrent users
