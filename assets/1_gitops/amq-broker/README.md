# Red Hat AMQ Broker

Enterprise messaging platform based on Apache ActiveMQ Artemis, providing high-performance message queuing and pub/sub capabilities.

## Overview

Red Hat AMQ Broker is a high-performance, non-blocking architecture messaging platform built on Apache ActiveMQ Artemis. It provides advanced queueing, messaging topologies, and protocols including AMQP 1.0, MQTT, STOMP, OpenWire, and HornetQ/Core.

## Components

This GitOps configuration deploys:

1. **AMQ Broker Operator** - Manages the lifecycle of AMQ Broker instances
2. **amq-broker Namespace** - Dedicated namespace for broker deployments

## Manifests

### 01-namespace.yaml
Creates the `amq-broker` namespace for broker deployments.

### 02-operatorgroup.yaml
Configures the OperatorGroup for the AMQ Broker operator, scoping it to the `amq-broker` namespace.

### 03-subscription.yaml
Subscribes to the AMQ Broker operator from Red Hat Operators catalog.

**Key settings:**
- Channel: `7.11.x`
- Install Plan Approval: `Automatic`
- Name: `amq-broker-rhel8`
- Namespace: `amq-broker`

## Deployment

### Via GitOps (Recommended)

The ArgoCD Application is defined in `apps/08-amq-broker.yaml` and will be automatically deployed when using the App-of-Apps pattern.

```bash
# Upload manifests and deploy
cd assets/1_gitops
./upload-and-deploy.sh
```

### Manual Deployment

```bash
# Apply manifests directly
oc apply -f amq-broker/manifests/

# Or via ArgoCD
oc apply -f apps/08-amq-broker.yaml
```

## Creating a Broker Instance

After the operator is installed, create an ActiveMQArtemis instance:

### Basic Broker

```yaml
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: ex-aao
  namespace: amq-broker
spec:
  deploymentPlan:
    size: 1
    image: placeholder
    requireLogin: false
    persistenceEnabled: false
    messageMigration: false
  console:
    expose: true
  acceptors:
    - name: amqp
      protocols: amqp
      port: 5672
    - name: mqtt
      protocols: mqtt
      port: 1883
```

Apply it:
```bash
oc apply -f broker.yaml -n amq-broker
```

### Production Broker with Persistence

```yaml
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: prod-broker
  namespace: amq-broker
spec:
  deploymentPlan:
    size: 2
    image: placeholder
    requireLogin: true
    persistenceEnabled: true
    messageMigration: true
    storage:
      size: 10Gi
    resources:
      limits:
        cpu: "1000m"
        memory: "2Gi"
      requests:
        cpu: "500m"
        memory: "1Gi"
  console:
    expose: true
  acceptors:
    - name: amqp
      protocols: amqp
      port: 5672
      sslEnabled: true
    - name: openwire
      protocols: openwire
      port: 61616
```

## Verification

Check deployment status:

```bash
# Check operator
oc get csv -n amq-broker | grep amq-broker

# Check operator pods
oc get pods -n amq-broker

# Check ActiveMQArtemis instances
oc get activemqartemis -n amq-broker

# Check broker pods
oc get pods -n amq-broker -l ActiveMQArtemis=ex-aao

# Check broker services
oc get svc -n amq-broker

# Check routes (if console is exposed)
oc get routes -n amq-broker
```

## Features

### High Performance
- Non-blocking I/O for maximum throughput
- Message paging to handle large volumes
- Optimized for both throughput and latency

### Multiple Protocols
- **AMQP 1.0**: Industry standard messaging protocol
- **MQTT**: Lightweight IoT protocol
- **STOMP**: Simple text-based protocol
- **OpenWire**: ActiveMQ Classic protocol
- **Core**: Native Artemis protocol

### High Availability
- Master-slave replication
- Automatic failover
- Live-live topology support
- Message redistribution

### Persistence
- File-based journal for durability
- Configurable paging
- Large message support

### Management
- Web-based management console
- JMX monitoring
- Hawtio integration
- Prometheus metrics

## Access Management Console

Once the broker is deployed with console exposure:

```bash
# Get console route
oc get route ex-aao-wconsj-0-svc-rte -n amq-broker

# Open in browser
echo "https://$(oc get route ex-aao-wconsj-0-svc-rte -n amq-broker -o jsonpath='{.spec.host}')"
```

Default credentials (if requireLogin: false):
- No authentication required

With authentication:
- Create secret for credentials first

## Creating Addresses and Queues

### Using Custom Resource

```yaml
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemisAddress
metadata:
  name: my-address
  namespace: amq-broker
spec:
  addressName: myAddress
  queueName: myQueue
  routingType: anycast
```

### Routing Types

- **anycast**: Point-to-point (queue semantics)
- **multicast**: Publish-subscribe (topic semantics)

## Configuration Examples

### Clustered Broker

```yaml
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: cluster-broker
  namespace: amq-broker
spec:
  deploymentPlan:
    size: 3
    clustered: true
    persistenceEnabled: true
  acceptors:
    - name: amqp
      protocols: amqp
      port: 5672
```

### Broker with Security

Create admin credentials:
```bash
oc create secret generic admin-credentials \
  --from-literal=username=admin \
  --from-literal=password=admin \
  -n amq-broker
```

Reference in broker:
```yaml
apiVersion: broker.amq.io/v1beta1
kind: ActiveMQArtemis
metadata:
  name: secure-broker
spec:
  adminUser: admin
  adminPassword: admin
  deploymentPlan:
    requireLogin: true
```

### SSL/TLS Configuration

Create TLS secret:
```bash
oc create secret generic broker-tls \
  --from-file=broker.ks=broker-keystore.jks \
  --from-file=client.ts=client-truststore.jks \
  --from-literal=keyStorePassword=password \
  --from-literal=trustStorePassword=password \
  -n amq-broker
```

Configure broker:
```yaml
spec:
  acceptors:
    - name: amqps
      protocols: amqp
      port: 5671
      sslEnabled: true
      sslSecret: broker-tls
```

## Client Examples

### AMQP Client (Python with Qpid Proton)

```python
from proton import Message
from proton.handlers import MessagingHandler
from proton.reactor import Container

class Send(MessagingHandler):
    def __init__(self, url, messages):
        super(Send, self).__init__()
        self.url = url
        self.sent = 0
        self.total = messages

    def on_start(self, event):
        event.container.create_sender(self.url)

    def on_sendable(self, event):
        while event.sender.credit and self.sent < self.total:
            msg = Message(body="Hello World %d" % self.sent)
            event.sender.send(msg)
            self.sent += 1

Container(Send("amqp://broker-url:5672/myQueue", 10)).run()
```

### MQTT Client (Python with Paho)

```python
import paho.mqtt.client as mqtt

def on_connect(client, userdata, flags, rc):
    print("Connected with result code "+str(rc))
    client.publish("test/topic", "Hello MQTT")

client = mqtt.Client()
client.on_connect = on_connect
client.connect("broker-url", 1883, 60)
client.loop_forever()
```

## Monitoring

### Prometheus Metrics

Enable metrics in broker:
```yaml
spec:
  console:
    expose: true
  brokerProperties:
    - "metricsPlugin={\"class\":\"org.apache.activemq.artemis.core.server.metrics.plugins.ArtemisPrometheusMetricsPlugin\"}"
```

Access metrics:
```bash
# Get metrics endpoint
oc get route ex-aao-wconsj-0-svc-rte -n amq-broker

# Curl metrics
curl https://<route-host>/metrics
```

### Key Metrics
- `artemis_message_count`: Number of messages in queues
- `artemis_messages_added`: Total messages added
- `artemis_messages_acknowledged`: Total messages acknowledged
- `artemis_consumer_count`: Number of consumers
- `artemis_address_memory_usage`: Memory usage per address

## Troubleshooting

### Broker Not Starting

```bash
# Check broker status
oc get activemqartemis ex-aao -n amq-broker -o yaml

# Check pods
oc get pods -n amq-broker -l ActiveMQArtemis=ex-aao

# Check pod logs
oc logs <pod-name> -n amq-broker

# Check events
oc get events -n amq-broker --sort-by='.lastTimestamp'
```

### Connection Issues

```bash
# Check services
oc get svc -n amq-broker

# Test connectivity from within cluster
oc run -it --rm test --image=curlimages/curl --restart=Never -- \
  sh -c "curl -v telnet://ex-aao-hdls-svc:5672"

# Check acceptor configuration
oc get activemqartemis ex-aao -n amq-broker \
  -o jsonpath='{.spec.acceptors}'
```

### Message Persistence Issues

```bash
# Check PVCs
oc get pvc -n amq-broker

# Check storage configuration
oc get activemqartemis ex-aao -n amq-broker \
  -o jsonpath='{.spec.deploymentPlan.storage}'

# Check broker logs for journal errors
oc logs <pod-name> -n amq-broker | grep -i journal
```

### Performance Issues

```bash
# Check resource limits
oc describe pod <pod-name> -n amq-broker | grep -A5 Limits

# Check memory usage
oc adm top pod -n amq-broker

# Review broker configuration for tuning
oc get activemqartemis ex-aao -n amq-broker -o yaml
```

## Common Workflows

### Deploy High-Availability Broker

1. Create broker with size: 2 or more
2. Enable persistence
3. Configure message redistribution
4. Set up load balancer for clients
5. Test failover scenarios

### Migrate Messages Between Brokers

1. Enable messageMigration in new broker
2. Deploy new broker
3. Update client connections
4. Verify message transfer
5. Decommission old broker

### Scale Broker Cluster

```bash
# Scale up
oc patch activemqartemis ex-aao -n amq-broker \
  --type merge -p '{"spec":{"deploymentPlan":{"size":3}}}'

# Scale down
oc patch activemqartemis ex-aao -n amq-broker \
  --type merge -p '{"spec":{"deploymentPlan":{"size":1}}}'
```

## Resource Requirements

Typical resource requirements:

- **Small Broker**: 500m CPU, 1Gi memory, 5Gi storage
- **Medium Broker**: 1 CPU, 2Gi memory, 20Gi storage
- **Large Broker**: 2 CPU, 4Gi memory, 50Gi storage
- **Cluster Node**: Add 25% overhead for clustering

## Integration

### With Applications
- Java clients via JMS API
- Python clients via Qpid Proton
- Node.js clients via AMQP 1.0
- MQTT clients for IoT devices

### With Camel/Integration
- Camel-AMQP component
- Camel-MQTT component
- Red Hat Integration / Fuse

### With Monitoring
- Prometheus for metrics
- Grafana for dashboards
- OpenShift monitoring integration

## Resources

- [Red Hat AMQ Broker Documentation](https://access.redhat.com/documentation/en-us/red_hat_amq_broker/)
- [Apache ActiveMQ Artemis Documentation](https://activemq.apache.org/components/artemis/)
- [AMQP 1.0 Specification](http://docs.oasis-open.org/amqp/core/v1.0/amqp-core-overview-v1.0.html)

## Notes

- **Protocol Support**: Supports multiple protocols simultaneously
- **Clustering**: Automatic cluster formation for HA
- **Persistence**: File-based journal for message durability
- **Management**: Full-featured web console included
- **Performance**: Optimized for high throughput and low latency
- **OpenShift Native**: Designed to run in containerized environments
