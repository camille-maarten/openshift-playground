# Red Hat OpenShift Service Mesh

Enterprise service mesh based on Istio, providing traffic management, security, and observability for microservices.

## Overview

Red Hat OpenShift Service Mesh is an enterprise-ready service mesh platform that provides sophisticated traffic management, security, and observability capabilities for microservices applications. It is based on the upstream Istio project and integrates with Jaeger for distributed tracing and Kiali for service mesh observability.

## Components

This GitOps configuration deploys:

1. **Elasticsearch Operator** - Provides storage backend for Jaeger distributed tracing
2. **Jaeger Operator** - Manages distributed tracing infrastructure
3. **Kiali Operator** - Provides service mesh observability and management console
4. **Service Mesh Operator** - Core operator that manages Istio-based service mesh components
5. **istio-system Namespace** - Default namespace for Service Mesh Control Plane

## Manifests

### 01-subscription-elasticsearch.yaml
Subscribes to the Elasticsearch operator from Red Hat Operators catalog.

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Namespace: `openshift-operators` (Elasticsearch-specific namespace)

### 02-subscription-jaeger.yaml
Subscribes to the Red Hat OpenShift distributed tracing platform (Jaeger).

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Namespace: `openshift-operators` (cluster-wide)
- Name: `jaeger-product`

### 03-subscription-kiali.yaml
Subscribes to the Kiali operator for service mesh observability.

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Namespace: `openshift-operators` (cluster-wide)
- Name: `kiali-ossm`

### 04-subscription-servicemesh.yaml
Subscribes to the main Service Mesh operator.

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Namespace: `openshift-operators` (cluster-wide)
- Name: `servicemeshoperator`

### 05-namespace-control-plane.yaml
Creates the `istio-system` namespace where the Service Mesh Control Plane will be deployed.

## Deployment

### Via GitOps (Recommended)

The ArgoCD Application is defined in `apps/06-service-mesh.yaml` and will be automatically deployed when using the App-of-Apps pattern.

```bash
# Upload manifests and deploy
cd assets/1_gitops
./upload-and-deploy.sh
```

### Manual Deployment

```bash
# Apply manifests directly
oc apply -f service-mesh/manifests/

# Or via ArgoCD
oc apply -f apps/06-service-mesh.yaml
```

## Creating a Service Mesh Control Plane

After the operators are installed, you need to create a ServiceMeshControlPlane resource:

### Example Control Plane

Create a file `servicemeshcontrolplane.yaml`:

```yaml
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  version: v2.5
  tracing:
    type: Jaeger
    sampling: 10000
  addons:
    jaeger:
      name: jaeger
      install:
        storage:
          type: Memory
    kiali:
      enabled: true
      name: kiali
    grafana:
      enabled: true
```

Apply it:
```bash
oc apply -f servicemeshcontrolplane.yaml -n istio-system
```

## Adding Projects to the Mesh

Create a ServiceMeshMemberRoll to specify which namespaces are part of the mesh:

```yaml
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
    - your-app-namespace
    - another-namespace
```

## Verification

Check deployment status:

```bash
# Check all operators
oc get csv -n openshift-operators | grep -E "(servicemesh|kiali|jaeger)"
oc get csv -n openshift-operators | grep elasticsearch

# Check operator pods
oc get pods -n openshift-operators | grep -E "(istio|kiali|jaeger)"
oc get pods -n openshift-operators | grep elasticsearch

# Check Service Mesh Control Plane (after creating one)
oc get smcp -n istio-system

# Check Service Mesh Member Roll
oc get smmr -n istio-system

# Check istio-system namespace
oc get pods -n istio-system
```

## Features

### Traffic Management
- Intelligent routing and load balancing
- A/B testing and canary deployments
- Traffic splitting and mirroring
- Circuit breaking and fault injection
- Request timeouts and retries

### Security
- Automatic mutual TLS (mTLS) between services
- Fine-grained authorization policies
- Certificate management
- Service-to-service authentication

### Observability
- Distributed tracing with Jaeger
- Service topology visualization with Kiali
- Metrics collection and monitoring
- Access logging

## Access Kiali Dashboard

Once the Service Mesh Control Plane is deployed:

```bash
# Get Kiali route
oc get route kiali -n istio-system

# Open in browser
echo "https://$(oc get route kiali -n istio-system -o jsonpath='{.spec.host}')"
```

Login using your OpenShift credentials.

## Access Jaeger Dashboard

```bash
# Get Jaeger route
oc get route jaeger -n istio-system

# Open in browser
echo "https://$(oc get route jaeger -n istio-system -o jsonpath='{.spec.host}')"
```

## Configuration

### Control Plane Profiles

Service Mesh provides several profiles:

- **default**: Production-ready configuration with all features
- **basic**: Minimal configuration for testing
- **preview**: Early access to upcoming features

Specify in ServiceMeshControlPlane:
```yaml
spec:
  profile: default  # or basic, preview
  version: v2.5
```

### Resource Limits

Adjust resource requirements:

```yaml
spec:
  runtime:
    components:
      pilot:
        container:
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

## Troubleshooting

### Operators Not Installing

```bash
# Check operator subscriptions
oc get subscriptions -n openshift-operators
oc get subscriptions -n openshift-operators

# Check install plans
oc get installplans -n openshift-operators
oc get installplans -n openshift-operators

# Check operator logs
oc logs -n openshift-operators -l name=istio-operator
```

### Control Plane Issues

```bash
# Check SMCP status
oc get smcp -n istio-system -o yaml

# Check conditions
oc get smcp basic -n istio-system -o jsonpath='{.status.conditions[*]}'

# Check control plane pods
oc get pods -n istio-system

# Check events
oc get events -n istio-system --sort-by='.lastTimestamp'
```

### Sidecar Injection Not Working

```bash
# Verify namespace is in member roll
oc get smmr -n istio-system

# Check namespace labels
oc get namespace your-namespace --show-labels

# Manually inject sidecar (for testing)
oc get deployment your-app -o yaml | \
  istioctl kube-inject -f - | \
  oc apply -f -
```

### Traffic Not Routing Correctly

```bash
# Check VirtualServices
oc get virtualservices -n your-namespace

# Check DestinationRules
oc get destinationrules -n your-namespace

# Check Gateways
oc get gateways -n istio-system

# View Envoy configuration in sidecar
oc exec -it your-pod -c istio-proxy -- pilot-agent request GET config_dump
```

## Common Workflows

### Deploy Application with Sidecar

1. Ensure namespace is in ServiceMeshMemberRoll
2. Deploy application normally
3. Sidecar is automatically injected
4. Verify: `oc get pods your-pod -o jsonpath='{.spec.containers[*].name}'`

### Configure Traffic Routing

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
    - myapp
  http:
    - match:
        - headers:
            version:
              exact: v2
      route:
        - destination:
            host: myapp
            subset: v2
    - route:
        - destination:
            host: myapp
            subset: v1
```

### Enable mTLS

```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
```

## Resource Requirements

Service Mesh is resource-intensive. Recommended minimum:

- **CPU**: 4 cores available for control plane
- **Memory**: 8 GB available for control plane
- **Additional**: Resources for sidecars (typically 100m CPU, 128Mi memory per pod)

## Integration

### Prometheus Integration
Service Mesh automatically integrates with OpenShift's built-in Prometheus for metrics collection.

### Grafana Dashboards
Pre-built Grafana dashboards are available for service mesh metrics visualization.

### OpenShift Routes
Service Mesh can be configured to work with OpenShift Routes for ingress traffic.

## Resources

- [Red Hat OpenShift Service Mesh Documentation](https://docs.openshift.com/container-platform/latest/service_mesh/v2x/ossm-about.html)
- [Istio Documentation](https://istio.io/latest/docs/)
- [Kiali Documentation](https://kiali.io/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)

## Notes

- **Operator Installation Order**: Elasticsearch → Jaeger → Kiali → Service Mesh
- **Version Compatibility**: Ensure operator versions are compatible with your OpenShift version
- **Cluster-wide Operators**: Most operators are installed cluster-wide in `openshift-operators`
- **Control Plane Namespace**: By convention, `istio-system` is used for the control plane
- **Sidecar Injection**: Automatic for namespaces in ServiceMeshMemberRoll
- **Performance Impact**: Sidecar proxies add latency (typically 1-5ms) and resource overhead
