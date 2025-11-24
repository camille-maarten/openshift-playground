# Red Hat OpenShift Serverless

Kubernetes-native serverless platform based on Knative, providing event-driven applications and auto-scaling capabilities.

## Overview

Red Hat OpenShift Serverless is a serverless application platform that provides Kubernetes-native primitives for deploying and running event-driven, scalable workloads. It is based on the upstream Knative project and includes:

- **Knative Serving**: Request-driven compute that can scale to zero
- **Knative Eventing**: Event-driven architecture with CloudEvents support

## Components

This GitOps configuration deploys:

1. **OpenShift Serverless Operator** - Core operator managing Knative components
2. **knative-serving Namespace** - Namespace for Knative Serving components
3. **knative-eventing Namespace** - Namespace for Knative Eventing components

## Manifests

### 00-namespace.yaml
Creates the `openshift-serverless` namespace for the operator.

### 01-subscription.yaml
Subscribes to the OpenShift Serverless operator from Red Hat Operators catalog.

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Namespace: `openshift-serverless`

### 02-namespace-serving.yaml
Creates the `knative-serving` namespace where Knative Serving components will be deployed.

### 03-namespace-eventing.yaml
Creates the `knative-eventing` namespace where Knative Eventing components will be deployed.

## Deployment

### Via GitOps (Recommended)

The ArgoCD Application is defined in `apps/07-serverless.yaml` and will be automatically deployed when using the App-of-Apps pattern.

```bash
# Upload manifests and deploy
cd assets/1_gitops
./upload-and-deploy.sh
```

### Manual Deployment

```bash
# Apply manifests directly
oc apply -f serverless/manifests/

# Or via ArgoCD
oc apply -f apps/07-serverless.yaml
```

## Enabling Knative Serving

After the operator is installed, create a KnativeServing instance:

```yaml
apiVersion: operator.knative.dev/v1beta1
kind: KnativeServing
metadata:
  name: knative-serving
  namespace: knative-serving
spec: {}
```

Apply it:
```bash
oc apply -f knativeserving.yaml -n knative-serving
```

## Enabling Knative Eventing

Create a KnativeEventing instance:

```yaml
apiVersion: operator.knative.dev/v1beta1
kind: KnativeEventing
metadata:
  name: knative-eventing
  namespace: knative-eventing
spec: {}
```

Apply it:
```bash
oc apply -f knativeeventing.yaml -n knative-eventing
```

## Verification

Check deployment status:

```bash
# Check operator
oc get csv -n openshift-serverless | grep serverless

# Check operator pods
oc get pods -n openshift-serverless

# Check Knative Serving (after creating KnativeServing)
oc get knativeserving -n knative-serving
oc get pods -n knative-serving

# Check Knative Eventing (after creating KnativeEventing)
oc get knativeeventing -n knative-eventing
oc get pods -n knative-eventing
```

## Features

### Knative Serving

**Scale-to-Zero:**
- Applications automatically scale to zero when not in use
- Sub-second cold start times
- Automatic scaling based on request load

**Traffic Splitting:**
- Blue/green deployments
- Canary releases
- A/B testing

**Revisions:**
- Immutable snapshots of application code and configuration
- Easy rollback to previous versions
- Traffic management across revisions

### Knative Eventing

**Event Sources:**
- Apache Kafka
- Apache Camel
- Kubernetes API Server
- Container sources
- Ping sources (cron-like)

**Event Brokers:**
- In-memory channel
- Kafka channel
- NATS channel

**Event Delivery:**
- At-least-once delivery
- Dead letter queues
- Retry policies

## Creating a Serverless Application

### Simple Knative Service

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: hello
  namespace: my-namespace
spec:
  template:
    spec:
      containers:
        - image: gcr.io/knative-samples/helloworld-go
          ports:
            - containerPort: 8080
          env:
            - name: TARGET
              value: "World"
```

Apply and access:
```bash
oc apply -f hello-service.yaml

# Get the URL
oc get ksvc hello -o jsonpath='{.status.url}'

# Test the service
curl $(oc get ksvc hello -o jsonpath='{.status.url}')
```

### Service with Auto-scaling Configuration

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: autoscale-app
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/target: "10"
        autoscaling.knative.dev/minScale: "1"
        autoscaling.knative.dev/maxScale: "100"
    spec:
      containers:
        - image: your-image:tag
```

## Event-Driven Architecture

### Create Event Source (Kafka)

```yaml
apiVersion: sources.knative.dev/v1beta1
kind: KafkaSource
metadata:
  name: kafka-source
  namespace: my-namespace
spec:
  consumerGroup: knative-group
  bootstrapServers:
    - my-cluster-kafka-bootstrap.kafka:9092
  topics:
    - my-topic
  sink:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: event-display
```

### Create Event Broker

```yaml
apiVersion: eventing.knative.dev/v1
kind: Broker
metadata:
  name: default
  namespace: my-namespace
```

### Create Trigger

```yaml
apiVersion: eventing.knative.dev/v1
kind: Trigger
metadata:
  name: my-trigger
  namespace: my-namespace
spec:
  broker: default
  filter:
    attributes:
      type: dev.knative.samples.hello
  subscriber:
    ref:
      apiVersion: serving.knative.dev/v1
      kind: Service
      name: hello
```

## Traffic Management

### Split Traffic Between Revisions

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: traffic-split
spec:
  template:
    metadata:
      name: traffic-split-v2
    spec:
      containers:
        - image: your-image:v2
  traffic:
    - revisionName: traffic-split-v1
      percent: 80
    - revisionName: traffic-split-v2
      percent: 20
```

## Configuration

### Global Auto-scaling Settings

Edit the KnativeServing resource:

```yaml
apiVersion: operator.knative.dev/v1beta1
kind: KnativeServing
metadata:
  name: knative-serving
  namespace: knative-serving
spec:
  config:
    autoscaler:
      scale-to-zero-grace-period: "30s"
      scale-to-zero-pod-retention-period: "0s"
      target-burst-capacity: "200"
      stable-window: "60s"
```

### Domain Configuration

Configure custom domains:

```yaml
spec:
  config:
    domain:
      example.com: |
        selector:
          app: prod
```

### High Availability

Enable HA for control plane:

```yaml
spec:
  high-availability:
    replicas: 2
```

## Monitoring

### View Service Status

```bash
# List all Knative services
oc get ksvc

# Get detailed service info
oc describe ksvc my-service

# View revisions
oc get revisions

# View routes
oc get routes.serving.knative.dev
```

### Metrics

Knative Serving provides metrics through Prometheus:

```bash
# Check metrics
oc get servicemonitor -n knative-serving
```

## Troubleshooting

### Service Not Accessible

```bash
# Check service status
oc get ksvc my-service -o yaml

# Check revision status
oc get revision -l serving.knative.dev/service=my-service

# Check route
oc get route.serving.knative.dev my-service

# Check pod logs
oc logs -l serving.knative.dev/service=my-service
```

### Service Not Scaling to Zero

```bash
# Check autoscaler config
oc get cm config-autoscaler -n knative-serving -o yaml

# Check service annotations
oc get ksvc my-service -o jsonpath='{.spec.template.metadata.annotations}'

# Force scale to zero
oc annotate ksvc my-service autoscaling.knative.dev/minScale=0
```

### Events Not Flowing

```bash
# Check broker status
oc get broker default -o yaml

# Check trigger status
oc get trigger my-trigger -o yaml

# Check event source
oc get kafkasource my-source -o yaml

# View events
oc get events -n my-namespace --sort-by='.lastTimestamp'
```

### Operator Issues

```bash
# Check operator logs
oc logs -n openshift-serverless -l name=knative-openshift

# Check KnativeServing status
oc get knativeserving knative-serving -n knative-serving -o yaml

# Check conditions
oc get knativeserving knative-serving -n knative-serving \
  -o jsonpath='{.status.conditions[*]}'
```

## Common Workflows

### Deploy New Version with Canary

1. Deploy new revision
2. Configure traffic split (e.g., 95% old, 5% new)
3. Monitor metrics and logs
4. Gradually increase traffic to new version
5. Complete rollout or rollback if issues

### Event-Driven Microservices

1. Create Kafka topics
2. Deploy Knative Services (event processors)
3. Create KafkaSource for each topic
4. Configure event delivery and retry policies
5. Monitor event flow with Kiali or Jaeger

### Scheduled Jobs with Events

1. Create PingSource with cron schedule
2. Point to Knative Service
3. Service scales up on event, processes, scales down

## Resource Requirements

OpenShift Serverless has minimal overhead:

- **Operator**: ~100m CPU, ~128Mi memory
- **Serving Components**: ~500m CPU, ~512Mi memory
- **Eventing Components**: ~300m CPU, ~384Mi memory
- **Per Application**: Varies based on configuration and scale

## Integration

### With Service Mesh
Knative Serving can integrate with OpenShift Service Mesh for:
- mTLS between services
- Traffic management
- Observability

### With Kafka
Native integration with Red Hat AMQ Streams (Kafka):
- KafkaSource for consuming events
- KafkaSink for producing events

### With OpenShift Routes
Serverless applications are exposed via standard OpenShift Routes.

## Resources

- [Red Hat OpenShift Serverless Documentation](https://docs.openshift.com/container-platform/latest/serverless/about/about-serverless.html)
- [Knative Documentation](https://knative.dev/docs/)
- [Knative Serving Documentation](https://knative.dev/docs/serving/)
- [Knative Eventing Documentation](https://knative.dev/docs/eventing/)

## Notes

- **Scale-to-Zero**: Applications can scale to zero replicas when idle
- **Cold Start**: Initial request to scaled-to-zero service may have latency
- **CloudEvents**: All events follow CloudEvents specification
- **Revisions**: Each deployment creates an immutable revision
- **Traffic Split**: Fine-grained traffic control between revisions
- **Auto-scaling**: Scales based on concurrency, RPS, or custom metrics
