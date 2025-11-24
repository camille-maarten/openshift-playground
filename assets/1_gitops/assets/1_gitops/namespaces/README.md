# OpenShift Namespaces

This directory contains namespace definitions and configurations for the OpenShift GitOps playground.

## Overview

Namespaces provide isolation and resource management for different workloads on the OpenShift cluster. This directory includes manifests for creating properly configured namespaces with resource quotas, limits, and network policies.

## Available Namespaces

### Playground Namespace

The `playground` namespace is designed for testing, experimentation, and sandbox activities.

**Purpose**:
- Testing new applications and configurations
- Experimenting with different deployment strategies
- Learning and training environment
- Proof-of-concept deployments

**Key Features**:
- Resource quotas to prevent resource exhaustion
- Limit ranges for default resource constraints
- Network policies for basic security
- Appropriate labels for organization and monitoring

## Namespace Configuration

### 1. Playground Namespace

**File**: `01-playground-namespace.yaml`

Creates the playground namespace with:
- **Name**: `playground`
- **Labels**:
  - `app.kubernetes.io/name: playground`
  - `app.kubernetes.io/component: sandbox`
  - `environment: development`
- **Annotations**:
  - Display name and description for OpenShift console

### 2. Resource Quota

**File**: `02-playground-resourcequota.yaml`

Limits total resource consumption in the namespace:

#### Compute Resources
- **CPU Requests**: 4 cores
- **CPU Limits**: 8 cores
- **Memory Requests**: 8Gi
- **Memory Limits**: 16Gi

#### Storage
- **Total Storage**: 50Gi
- **PVCs**: Maximum 10 persistent volume claims

#### Object Counts
- **Pods**: 20
- **Services**: 10
- **ConfigMaps**: 20
- **Secrets**: 20
- **Deployments**: 10
- **StatefulSets**: 5
- **Jobs**: 10

### 3. Limit Range

**File**: `03-playground-limitrange.yaml`

Sets default and maximum limits for individual resources:

#### Container Defaults
- **Default CPU**: 200m
- **Default Memory**: 256Mi
- **Default CPU Request**: 100m
- **Default Memory Request**: 128Mi

#### Container Limits
- **Max CPU**: 2 cores per container
- **Max Memory**: 4Gi per container
- **Min CPU**: 10m per container
- **Min Memory**: 10Mi per container

#### Pod Limits
- **Max CPU**: 2 cores per pod
- **Max Memory**: 4Gi per pod

#### PVC Limits
- **Max Storage**: 10Gi per PVC
- **Min Storage**: 1Gi per PVC

### 4. Network Policy

**File**: `04-playground-networkpolicy.yaml`

Controls network traffic in/out of the namespace:

#### Ingress Rules
- ✅ Allow traffic from pods in the same namespace
- ✅ Allow traffic from OpenShift ingress controller
- ❌ Deny traffic from other namespaces (by default)

#### Egress Rules
- ✅ Allow traffic to pods in the same namespace
- ✅ Allow DNS resolution (UDP port 53)
- ✅ Allow external HTTPS traffic (TCP port 443)
- ✅ Allow external HTTP traffic (TCP port 80)

## Installation

### Prerequisites

- OpenShift cluster with cluster-admin access
- OpenShift GitOps (ArgoCD) installed (for GitOps installation)

### Installation Methods

#### Method 1: ArgoCD Installation (Recommended - Coming Soon)

ArgoCD Application manifest will be added in a later stage for GitOps-based installation.

#### Method 2: Manual Installation

Install the namespace manually using `oc` commands:

```bash
cd assets/1_gitops/namespaces/manifests

# Create playground namespace
oc apply -f 01-playground-namespace.yaml

# Apply resource quota
oc apply -f 02-playground-resourcequota.yaml

# Apply limit range
oc apply -f 03-playground-limitrange.yaml

# Apply network policy
oc apply -f 04-playground-networkpolicy.yaml
```

### Verify Installation

Check the namespace and its configurations:

```bash
# Verify namespace exists
oc get namespace playground

# Check resource quota
oc get resourcequota -n playground
oc describe resourcequota playground-quota -n playground

# Check limit range
oc get limitrange -n playground
oc describe limitrange playground-limits -n playground

# Check network policy
oc get networkpolicy -n playground
oc describe networkpolicy allow-same-namespace -n playground

# View namespace in OpenShift console
oc project playground
```

## Usage Examples

### Deploy a Test Application

```bash
# Switch to playground namespace
oc project playground

# Create a simple deployment
oc create deployment nginx --image=nginx:latest

# Expose the deployment
oc expose deployment nginx --port=80

# Create a route
oc expose service nginx

# Get the route URL
oc get route nginx
```

### Check Resource Usage

```bash
# View current resource usage
oc describe resourcequota playground-quota -n playground

# View pod resource allocations
oc get pods -n playground -o custom-columns=\
NAME:.metadata.name,\
CPU_REQUEST:.spec.containers[*].resources.requests.cpu,\
MEMORY_REQUEST:.spec.containers[*].resources.requests.memory,\
CPU_LIMIT:.spec.containers[*].resources.limits.cpu,\
MEMORY_LIMIT:.spec.containers[*].resources.limits.memory
```

### Test Network Policy

```bash
# Deploy a test pod
oc run test-pod --image=nginx -n playground

# Test connectivity within namespace
oc exec -it test-pod -n playground -- curl http://nginx

# Test external connectivity
oc exec -it test-pod -n playground -- curl https://www.google.com
```

## Customization

### Adjusting Resource Quotas

To modify resource quotas, edit `02-playground-resourcequota.yaml`:

```yaml
spec:
  hard:
    requests.cpu: "8"      # Change from 4 to 8
    requests.memory: "16Gi" # Change from 8Gi to 16Gi
```

Then apply the changes:

```bash
oc apply -f 02-playground-resourcequota.yaml
```

### Modifying Limit Ranges

To change default container limits, edit `03-playground-limitrange.yaml`:

```yaml
- type: Container
  default:
    cpu: "500m"    # Change from 200m
    memory: "512Mi" # Change from 256Mi
```

Apply the changes:

```bash
oc apply -f 03-playground-limitrange.yaml
```

### Updating Network Policies

To allow traffic from specific namespaces, edit `04-playground-networkpolicy.yaml`:

```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            name: my-other-namespace
```

## Troubleshooting

### Quota Exceeded Errors

If you see "exceeded quota" errors:

```bash
# Check current usage
oc describe resourcequota playground-quota -n playground

# List resource-heavy pods
oc get pods -n playground --sort-by=.spec.containers[0].resources.requests.cpu

# Delete unused resources
oc delete pod <pod-name> -n playground
```

### Pods Not Starting Due to Limits

If pods fail to start due to resource limits:

```bash
# Check pod events
oc describe pod <pod-name> -n playground

# View limit range
oc describe limitrange playground-limits -n playground

# Adjust pod resource requests/limits or modify the LimitRange
```

### Network Connectivity Issues

If pods cannot communicate:

```bash
# Check network policy
oc get networkpolicy -n playground
oc describe networkpolicy allow-same-namespace -n playground

# Test connectivity
oc run test --rm -it --image=busybox -n playground -- sh
# Inside pod: wget -O- http://service-name:port
```

## Monitoring

### View Namespace Metrics

```bash
# Get resource usage summary
oc adm top pods -n playground

# View namespace-level metrics
oc adm top namespace playground

# Check quota usage over time (requires monitoring stack)
oc get resourcequota playground-quota -n playground -w
```

## Cleanup

### Delete All Resources in Namespace

```bash
# Delete all deployments
oc delete deployment --all -n playground

# Delete all pods
oc delete pods --all -n playground

# Delete all services
oc delete service --all -n playground
```

### Delete the Namespace

**Warning**: This will delete all resources in the namespace.

```bash
# Using ArgoCD (when available)
oc delete application playground-namespace -n openshift-gitops

# Manual deletion
oc delete namespace playground
```

## Best Practices

1. **Resource Requests and Limits**
   - Always specify resource requests and limits for production workloads
   - Use the defaults provided by LimitRange as a starting point
   - Monitor actual usage and adjust accordingly

2. **Network Policies**
   - Follow principle of least privilege
   - Only allow necessary traffic
   - Document any policy exceptions

3. **Quota Management**
   - Regularly review resource usage
   - Adjust quotas based on actual needs
   - Set alerts for quota thresholds

4. **Labeling**
   - Use consistent labels across resources
   - Include environment, component, and owner labels
   - Enable better filtering and organization

## Security Considerations

- **Network Isolation**: NetworkPolicy provides basic isolation but may need refinement
- **Resource Limits**: Prevents resource exhaustion and noisy neighbor issues
- **RBAC**: Additional RoleBindings may be needed for user access
- **Pod Security**: Consider adding Pod Security Standards/Admission

## Adding More Namespaces

To add additional namespaces, follow this pattern:

1. Create namespace YAML with appropriate labels and annotations
2. Define ResourceQuota based on expected workload
3. Set LimitRange for default resource constraints
4. Configure NetworkPolicy for security requirements
5. Document the namespace purpose and configuration

Example file naming:
- `05-<namespace-name>-namespace.yaml`
- `06-<namespace-name>-resourcequota.yaml`
- `07-<namespace-name>-limitrange.yaml`
- `08-<namespace-name>-networkpolicy.yaml`

## References

- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
- [OpenShift Projects](https://docs.openshift.com/container-platform/latest/applications/projects/working-with-projects.html)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
