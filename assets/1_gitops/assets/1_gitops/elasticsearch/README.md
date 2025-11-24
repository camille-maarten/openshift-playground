# Elasticsearch (ECK Operator)

Enterprise search and analytics engine managed by Elastic Cloud on Kubernetes (ECK) operator.

## Overview

Elasticsearch is a distributed, RESTful search and analytics engine capable of addressing a growing number of use cases. The ECK (Elastic Cloud on Kubernetes) operator makes it easy to deploy, manage, and operate Elasticsearch clusters on OpenShift.

This deployment uses the certified ECK operator from the certified-operators catalog.

## Components

This GitOps configuration deploys:

1. **ECK Operator** - Elastic Cloud on Kubernetes operator for managing Elasticsearch, Kibana, and other Elastic Stack components
2. **elastic-system Namespace** - Dedicated namespace for Elasticsearch deployments

## Manifests

### 01-namespace.yaml
Creates the `elastic-system` namespace for Elasticsearch deployments.

### 02-operatorgroup.yaml
Configures the OperatorGroup for the ECK operator, scoping it to the `elastic-system` namespace.

### 03-subscription.yaml
Subscribes to the ECK operator from the certified operators catalog.

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Name: `elasticsearch-eck-operator-certified`
- Source: `certified-operators`
- Namespace: `elastic-system`

## Deployment

### Via GitOps (Recommended)

The ArgoCD Application is defined in `apps/09-elasticsearch.yaml` and will be automatically deployed when using the App-of-Apps pattern.

```bash
# Upload manifests and deploy
cd assets/1_gitops
./upload-and-deploy.sh
```

### Manual Deployment

```bash
# Apply manifests directly
oc apply -f elasticsearch/manifests/

# Or via ArgoCD
oc apply -f apps/09-elasticsearch.yaml
```

## Creating an Elasticsearch Cluster

After the operator is installed, create an Elasticsearch cluster:

### Simple Single-Node Cluster

```yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
  namespace: elastic-system
spec:
  version: 8.11.0
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
```

Apply it:
```bash
oc apply -f elasticsearch.yaml -n elastic-system
```

### Production Multi-Node Cluster

```yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: production
  namespace: elastic-system
spec:
  version: 8.11.0
  nodeSets:
  - name: master
    count: 3
    config:
      node.roles: ["master"]
      node.store.allow_mmap: false
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
  - name: data
    count: 3
    config:
      node.roles: ["data", "ingest"]
      node.store.allow_mmap: false
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            limits:
              memory: 4Gi
              cpu: 2
            requests:
              memory: 4Gi
              cpu: 1
```

## Verification

Check deployment status:

```bash
# Check operator
oc get csv -n elastic-system | grep elastic

# Check operator pods
oc get pods -n elastic-system

# Check Elasticsearch clusters
oc get elasticsearch -n elastic-system

# Check cluster health
oc get elasticsearch quickstart -n elastic-system

# Check cluster pods
oc get pods -n elastic-system -l elasticsearch.k8s.elastic.co/cluster-name=quickstart

# Check services
oc get svc -n elastic-system
```

## Deploying Kibana

Create a Kibana instance to visualize Elasticsearch data:

```yaml
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart
  namespace: elastic-system
spec:
  version: 8.11.0
  count: 1
  elasticsearchRef:
    name: quickstart
  http:
    tls:
      selfSignedCertificate:
        disabled: true
```

Apply it:
```bash
oc apply -f kibana.yaml -n elastic-system
```

## Access Elasticsearch

### Get Credentials

```bash
# Get the elastic user password
PASSWORD=$(oc get secret quickstart-es-elastic-user -n elastic-system -o go-template='{{.data.elastic | base64decode}}')
echo "Password: $PASSWORD"
```

### Access via Service

```bash
# Port-forward to access locally
oc port-forward svc/quickstart-es-http 9200:9200 -n elastic-system

# Test connection (in another terminal)
curl -u "elastic:$PASSWORD" -k "https://localhost:9200"
```

### Create Route (for external access)

```bash
# Create route
oc create route passthrough quickstart-es --service=quickstart-es-http -n elastic-system

# Get route URL
echo "https://$(oc get route quickstart-es -n elastic-system -o jsonpath='{.spec.host}')"

# Test
curl -u "elastic:$PASSWORD" -k "https://$(oc get route quickstart-es -n elastic-system -o jsonpath='{.spec.host}')"
```

## Access Kibana

```bash
# Create route for Kibana
oc create route edge kibana --service=quickstart-kb-http -n elastic-system

# Get Kibana URL
echo "https://$(oc get route kibana -n elastic-system -o jsonpath='{.spec.host}')"

# Login with:
# Username: elastic
# Password: $PASSWORD (from above)
```

## Features

### Full-Text Search
- Advanced query DSL
- Multi-field search
- Fuzzy matching and typo tolerance
- Highlighting and suggestions

### Analytics
- Aggregations and metrics
- Time-series analysis
- Geospatial queries
- Machine learning anomaly detection

### Scalability
- Horizontal scaling with multiple nodes
- Automatic shard allocation
- Index lifecycle management
- Cross-cluster replication

### High Availability
- Automatic failover
- Replica shards for redundancy
- Snapshot and restore
- Cross-cluster search

## Configuration Examples

### With Persistent Storage

```yaml
spec:
  nodeSets:
  - name: default
    count: 3
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi
        storageClassName: gp3
```

### With Resource Limits

```yaml
spec:
  nodeSets:
  - name: default
    count: 3
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 2Gi
              cpu: 1
            limits:
              memory: 2Gi
              cpu: 2
```

### With TLS Disabled (for testing)

```yaml
spec:
  http:
    tls:
      selfSignedCertificate:
        disabled: true
```

### With Custom Configuration

```yaml
spec:
  nodeSets:
  - name: default
    count: 3
    config:
      node.store.allow_mmap: false
      xpack.security.enabled: true
      xpack.monitoring.collection.enabled: true
```

## Index Management

### Create Index

```bash
curl -X PUT "https://quickstart-es-http:9200/my-index" \
  -u "elastic:$PASSWORD" \
  -k \
  -H 'Content-Type: application/json' \
  -d '{
    "settings": {
      "number_of_shards": 3,
      "number_of_replicas": 1
    }
  }'
```

### Index Documents

```bash
curl -X POST "https://quickstart-es-http:9200/my-index/_doc" \
  -u "elastic:$PASSWORD" \
  -k \
  -H 'Content-Type: application/json' \
  -d '{
    "user": "john",
    "message": "Hello Elasticsearch"
  }'
```

### Search Documents

```bash
curl -X GET "https://quickstart-es-http:9200/my-index/_search" \
  -u "elastic:$PASSWORD" \
  -k \
  -H 'Content-Type: application/json' \
  -d '{
    "query": {
      "match": {
        "message": "Elasticsearch"
      }
    }
  }'
```

## Monitoring

### Cluster Health

```bash
curl -u "elastic:$PASSWORD" -k \
  "https://quickstart-es-http:9200/_cluster/health?pretty"
```

### Node Stats

```bash
curl -u "elastic:$PASSWORD" -k \
  "https://quickstart-es-http:9200/_nodes/stats?pretty"
```

### Index Stats

```bash
curl -u "elastic:$PASSWORD" -k \
  "https://quickstart-es-http:9200/_stats?pretty"
```

## Troubleshooting

### Cluster Not Starting

```bash
# Check Elasticsearch resource
oc get elasticsearch quickstart -n elastic-system -o yaml

# Check pod status
oc get pods -n elastic-system -l elasticsearch.k8s.elastic.co/cluster-name=quickstart

# Check pod logs
oc logs <pod-name> -n elastic-system

# Check events
oc get events -n elastic-system --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Check PVCs
oc get pvc -n elastic-system

# Check PVC status
oc describe pvc elasticsearch-data-quickstart-es-default-0 -n elastic-system

# Check disk usage in pod
oc exec -it quickstart-es-default-0 -n elastic-system -- df -h
```

### Connection Issues

```bash
# Check service
oc get svc quickstart-es-http -n elastic-system

# Test connectivity from within cluster
oc run -it --rm test --image=curlimages/curl --restart=Never -n elastic-system -- \
  curl -u "elastic:$PASSWORD" -k https://quickstart-es-http:9200

# Check certificates
oc get secret quickstart-es-http-certs-public -n elastic-system
```

### Performance Issues

```bash
# Check resource usage
oc adm top pod -n elastic-system

# Check cluster stats
curl -u "elastic:$PASSWORD" -k \
  "https://quickstart-es-http:9200/_cluster/stats?pretty"

# Check slow logs
oc logs <pod-name> -n elastic-system | grep -i slow
```

## Common Workflows

### Backup and Restore

Create snapshot repository:
```bash
curl -X PUT "https://quickstart-es-http:9200/_snapshot/my_backup" \
  -u "elastic:$PASSWORD" \
  -k \
  -H 'Content-Type: application/json' \
  -d '{
    "type": "fs",
    "settings": {
      "location": "/usr/share/elasticsearch/backup"
    }
  }'
```

Create snapshot:
```bash
curl -X PUT "https://quickstart-es-http:9200/_snapshot/my_backup/snapshot_1" \
  -u "elastic:$PASSWORD" -k
```

### Scale Cluster

```bash
# Scale up data nodes
oc patch elasticsearch quickstart -n elastic-system \
  --type merge -p '{"spec":{"nodeSets":[{"name":"default","count":5}]}}'

# Scale down
oc patch elasticsearch quickstart -n elastic-system \
  --type merge -p '{"spec":{"nodeSets":[{"name":"default","count":3}]}}'
```

### Upgrade Cluster

```bash
# Update version
oc patch elasticsearch quickstart -n elastic-system \
  --type merge -p '{"spec":{"version":"8.12.0"}}'

# ECK performs rolling upgrade automatically
```

## Resource Requirements

Typical resource requirements per node:

- **Development**: 1 CPU, 2Gi memory, 10Gi storage
- **Small Production**: 2 CPU, 4Gi memory, 50Gi storage
- **Medium Production**: 4 CPU, 8Gi memory, 200Gi storage
- **Large Production**: 8 CPU, 16Gi memory, 1Ti storage

## Integration

### With Applications
- REST API for all operations
- Client libraries for multiple languages
- Logstash for data ingestion
- Beats for data collection

### With OpenShift Logging
- Can be used as logging backend
- Fluentd/Vector for log forwarding
- Kibana for log visualization

### With Monitoring
- Prometheus exporter available
- Grafana dashboards
- Built-in monitoring features

## Resources

- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html)
- [ECK Documentation](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)
- [Kibana Documentation](https://www.elastic.co/guide/en/kibana/current/index.html)

## Notes

- **Memory Settings**: Elasticsearch requires heap size to be set (typically 50% of pod memory)
- **mmap**: Disabled by default on OpenShift for security (`node.store.allow_mmap: false`)
- **TLS**: ECK automatically configures TLS between nodes
- **Licensing**: Basic license is free; advanced features require subscription
- **Versions**: Keep Elasticsearch and Kibana versions in sync
- **Upgrade Path**: Follow Elasticsearch upgrade guidelines (can't skip major versions)
