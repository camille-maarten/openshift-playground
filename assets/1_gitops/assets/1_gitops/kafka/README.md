# Red Hat Streams for Apache Kafka (AMQ Streams)

This directory contains the manifests to install the Red Hat Streams for Apache Kafka operator (AMQ Streams) on OpenShift.

## Overview

Red Hat AMQ Streams is based on the open-source Apache Kafka project and provides a distributed streaming platform for:
- Publishing and subscribing to streams of records
- Storing streams of records in a fault-tolerant way
- Processing streams of records as they occur

This installation sets up the **AMQ Streams operator** which manages Kafka clusters on OpenShift.

## What This Installation Includes

The manifests install **only the operator**, not a Kafka cluster. This provides:

- **AMQ Streams Operator**: Manages Kafka cluster lifecycle
- **Custom Resource Definitions (CRDs)**: For Kafka, KafkaConnect, KafkaTopic, KafkaUser, etc.
- **Operator Namespace**: Dedicated `kafka` namespace for the operator

**Note**: To deploy actual Kafka clusters, topics, users, or connectors, you'll need to create additional Custom Resources after the operator is installed. This will be done in a later stage.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AMQ Streams Operator                      │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          Cluster Operator (Strimzi)                  │   │
│  │  - Manages Kafka clusters                            │   │
│  │  - Manages ZooKeeper ensembles                       │   │
│  │  - Manages KafkaConnect clusters                     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          Topic Operator                              │   │
│  │  - Manages KafkaTopic resources                      │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          User Operator                               │   │
│  │  - Manages KafkaUser resources                       │   │
│  │  - Manages ACLs and SCRAM credentials                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Installation

### Prerequisites

- OpenShift cluster with cluster-admin access
- OpenShift GitOps (ArgoCD) installed (for GitOps installation)
- Red Hat AMQ Streams operator available in OperatorHub

### Installation Methods

#### Method 1: ArgoCD Installation (Recommended - Coming Soon)

ArgoCD Application manifest will be added in a later stage for GitOps-based installation.

#### Method 2: Manual Installation

Install the operator manually using `oc` commands:

```bash
cd assets/1_gitops/kafka/manifests

# Create namespace
oc apply -f 01-namespace.yaml

# Create operator group
oc apply -f 02-operatorgroup.yaml

# Subscribe to AMQ Streams operator
oc apply -f 03-subscription.yaml

# Wait for operator to be ready
oc wait --for=condition=Ready pod -l name=amq-streams-cluster-operator -n kafka --timeout=300s
```

### Verify Installation

Check that the operator is running:

```bash
# Check operator deployment
oc get csv -n kafka

# Check operator pods
oc get pods -n kafka

# Verify CRDs are installed
oc get crd | grep kafka
```

Expected CRDs:
- `kafkas.kafka.strimzi.io`
- `kafkatopics.kafka.strimzi.io`
- `kafkausers.kafka.strimzi.io`
- `kafkaconnects.kafka.strimzi.io`
- `kafkaconnectors.kafka.strimzi.io`
- `kafkamirrormakers.kafka.strimzi.io`
- `kafkamirrormaker2s.kafka.strimzi.io`
- `kafkabridges.kafka.strimzi.io`
- `kafkarebalances.kafka.strimzi.io`

## Next Steps

After the operator is installed, you can deploy Kafka resources:

### 1. Deploy a Kafka Cluster

Example Kafka cluster (will be added in later stages):

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
  namespace: kafka
spec:
  kafka:
    version: 3.6.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    config:
      offsets.topic.replication.factor: 3
      transaction.state.log.replication.factor: 3
      transaction.state.log.min.isr: 2
      default.replication.factor: 3
      min.insync.replicas: 2
    storage:
      type: persistent-claim
      size: 10Gi
      class: gp2
  zookeeper:
    replicas: 3
    storage:
      type: persistent-claim
      size: 5Gi
      class: gp2
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

### 2. Create Kafka Topics

Example topic creation:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: my-topic
  namespace: kafka
  labels:
    strimzi.io/cluster: my-cluster
spec:
  partitions: 3
  replicas: 3
  config:
    retention.ms: 7200000
    segment.bytes: 1073741824
```

### 3. Create Kafka Users

Example user creation with ACLs:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaUser
metadata:
  name: my-user
  namespace: kafka
  labels:
    strimzi.io/cluster: my-cluster
spec:
  authentication:
    type: scram-sha-512
  authorization:
    type: simple
    acls:
      - resource:
          type: topic
          name: my-topic
          patternType: literal
        operations:
          - Read
          - Write
          - Describe
      - resource:
          type: group
          name: my-group
          patternType: literal
        operations:
          - Read
```

## Operator Configuration

### Namespace Strategy

This installation uses a **namespace-scoped** operator that:
- Runs in the `kafka` namespace
- Manages Kafka resources only in the `kafka` namespace
- Provides better isolation and resource management

### Channel and Updates

The operator is subscribed to the **stable** channel:
- Automatic updates within the stable channel
- Production-ready releases
- Conservative update strategy

To pin to a specific version, add `startingCSV` to the subscription:

```yaml
spec:
  startingCSV: amqstreams.v2.6.0-0
```

## Troubleshooting

### Check Operator Status

```bash
# View CSV (ClusterServiceVersion)
oc get csv -n kafka

# View operator deployment
oc get deployment -n kafka

# View operator logs
oc logs -f deployment/amq-streams-cluster-operator -n kafka
```

### Common Issues

1. **Operator Not Starting**
   - Check operator logs: `oc logs -f deployment/amq-streams-cluster-operator -n kafka`
   - Verify subscription: `oc get subscription amq-streams -n kafka -o yaml`
   - Check install plan: `oc get installplan -n kafka`

2. **CRDs Not Created**
   - Verify operator is running: `oc get pods -n kafka`
   - Check for CRDs: `oc get crd | grep kafka`
   - Review operator logs for errors

3. **Kafka Cluster Not Deploying**
   - Ensure operator is ready before creating Kafka CR
   - Check operator logs for reconciliation errors
   - Verify storage class exists: `oc get storageclass`

## Uninstallation

### Using ArgoCD (Future)

When ArgoCD Application is available:

```bash
# Delete ArgoCD Application
oc delete application kafka-operator -n openshift-gitops

# Delete namespace
oc delete namespace kafka
```

### Manual Uninstallation

To remove the operator:

```bash
# Delete any Kafka clusters first (if created)
oc delete kafka --all -n kafka

# Delete subscription
oc delete subscription amq-streams -n kafka

# Delete CSV
oc delete csv -n kafka -l operators.coreos.com/amq-streams.kafka

# Delete operator group
oc delete operatorgroup kafka-operator-group -n kafka

# Delete namespace
oc delete namespace kafka
```

**Warning**: Deleting the operator will also delete all Kafka clusters, topics, and users managed by it.

## Resources and References

- [Red Hat AMQ Streams Documentation](https://access.redhat.com/documentation/en-us/red_hat_amq_streams)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Strimzi Documentation](https://strimzi.io/documentation/)
- [AMQ Streams on OpenShift](https://developers.redhat.com/products/amq/overview)

## Supported Versions

- **Kafka Version**: 3.6.x (configurable in Kafka CR)
- **Operator Version**: 2.6.x (from stable channel)
- **OpenShift**: 4.12+

## What's Next

In future stages, this directory will include:
- ArgoCD Application manifest for GitOps deployment
- Example Kafka cluster configurations
- Sample KafkaTopic and KafkaUser resources
- KafkaConnect configurations
- Monitoring and observability setup
