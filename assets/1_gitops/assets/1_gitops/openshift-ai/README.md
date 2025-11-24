# Red Hat OpenShift AI

Enterprise-ready AI/ML platform for developing, training, and serving machine learning models at scale.

## Overview

Red Hat OpenShift AI (formerly Red Hat OpenShift Data Science) is an AI/ML platform that provides data scientists and developers with a collaborative environment for the full machine learning lifecycle. It includes tools for data preparation, model development, training, serving, and monitoring.

## Components

This GitOps configuration deploys:

1. **RHODS Operator** - Manages the lifecycle of OpenShift AI components
2. **DataScienceCluster** - Configures and enables AI/ML platform components

## Manifests

### 01-subscription.yaml
Subscribes to the `rhods-operator` from the Red Hat Operators catalog.

**Key settings:**
- Channel: `stable`
- Install Plan Approval: `Automatic`
- Source: `redhat-operators`
- Namespace: `openshift-operators` (cluster-wide operator)

### 02-datasciencecluster.yaml
Defines the Data Science Cluster with all components enabled:

**Enabled Components:**

1. **Dashboard**
   - Web-based interface for managing AI/ML workloads
   - Jupyter notebook launcher
   - Model serving UI

2. **Workbenches**
   - Jupyter notebooks with various ML frameworks
   - Pre-configured images with popular libraries
   - Persistent storage for notebooks

3. **Data Science Pipelines**
   - Kubeflow Pipelines integration
   - Workflow orchestration for ML pipelines
   - Experiment tracking and versioning

4. **Model Serving**
   - **KServe**: Advanced model serving with auto-scaling
   - **ModelMesh**: Multi-model serving for efficient resource usage
   - Support for multiple frameworks (TensorFlow, PyTorch, etc.)

5. **Distributed Training**
   - **CodeFlare**: Simplified distributed computing
   - **Ray**: Scalable Python framework for ML workloads
   - GPU support for training acceleration

## Deployment

### Via GitOps (Recommended)

The ArgoCD Application is defined in `apps/05-openshift-ai.yaml` and will be automatically deployed when using the App-of-Apps pattern.

```bash
# Upload manifests and deploy
cd assets/1_gitops
./upload-and-deploy.sh
```

### Manual Deployment

```bash
# Apply manifests directly
oc apply -f openshift-ai/manifests/

# Or via ArgoCD
oc apply -f apps/05-openshift-ai.yaml
```

## Access

Once deployed, access OpenShift AI Dashboard:

1. **Get the route:**
   ```bash
   oc get route rhods-dashboard -n redhat-ods-applications
   ```

2. **Open in browser:**
   ```bash
   echo "https://$(oc get route rhods-dashboard -n redhat-ods-applications -o jsonpath='{.spec.host}')"
   ```

3. **Login** using your OpenShift credentials

## Key Features

### Jupyter Notebooks
- **Pre-built Images**: Standard, TensorFlow, PyTorch, CUDA notebooks
- **Custom Images**: Add your own notebook images
- **Persistent Storage**: PVCs automatically attached to workbenches
- **Collaborative**: Share notebooks across teams

### Model Development
- **Experiment Tracking**: Track experiments and metrics
- **Version Control**: Git integration for notebook versioning
- **Data Sources**: Connect to S3, databases, and data lakes
- **Environment Variables**: Securely manage credentials

### Model Training
- **Distributed Training**: Scale training across multiple nodes
- **GPU Support**: Leverage NVIDIA GPUs for acceleration
- **Pipeline Automation**: Automate training workflows
- **Hyperparameter Tuning**: Optimize model parameters

### Model Serving
- **Multi-Framework**: TensorFlow, PyTorch, Scikit-learn, XGBoost
- **Auto-scaling**: Scale based on inference load
- **A/B Testing**: Deploy multiple model versions
- **Monitoring**: Track model performance and drift

## Verification

Check deployment status:

```bash
# Check operator
oc get csv -n openshift-operators | grep rhods

# Check DataScienceCluster
oc get datasciencecluster

# Check all OpenShift AI pods
oc get pods -n redhat-ods-applications
oc get pods -n redhat-ods-operator
oc get pods -n redhat-ods-monitoring

# Check routes
oc get routes -n redhat-ods-applications
```

## Component Details

### Dashboard Component
Provides web UI for:
- Launching Jupyter notebooks
- Managing data science projects
- Accessing model serving
- Viewing documentation

### CodeFlare Component
Enables:
- Distributed Python workloads
- Ray cluster management
- Resource allocation for ML jobs

### Data Science Pipelines
Provides:
- Visual pipeline editor
- Pipeline versioning
- Artifact storage
- Experiment tracking

### KServe Component
Features:
- Serverless model deployment
- Auto-scaling inference
- Traffic splitting for canary deployments
- OpenShift Service Mesh integration

### ModelMesh Component
Offers:
- Multi-model serving
- Intelligent model placement
- Resource optimization
- Quick model loading/unloading

### Ray Component
Enables:
- Distributed data processing
- Parallel hyperparameter tuning
- Reinforcement learning
- Scalable ML workloads

### Workbenches Component
Includes:
- Notebook spawner
- Image management
- PVC automation
- Environment configuration

## Configuration

### Enable/Disable Components

Modify `02-datasciencecluster.yaml` to control components:

```yaml
spec:
  components:
    dashboard:
      managementState: Managed  # or Removed to disable
```

**Management States:**
- `Managed`: Component is installed and managed
- `Removed`: Component is not installed

### Configure KServe Serving

Customize serving configuration:

```yaml
spec:
  components:
    kserve:
      serving:
        ingressGateway:
          certificate:
            type: SelfSigned  # or OpenshiftDefaultIngress
```

## Troubleshooting

### Operator Issues

```bash
# Check operator logs
oc logs -n redhat-ods-operator -l name=rhods-operator

# Check operator status
oc get csv -n openshift-operators | grep rhods
```

### DataScienceCluster Not Ready

```bash
# Check DSC status
oc get datasciencecluster default-dsc -o yaml

# Check conditions
oc get datasciencecluster default-dsc -o jsonpath='{.status.conditions[*]}'
```

### Component Issues

```bash
# Check specific component pods
oc get pods -n redhat-ods-applications -l app=<component-name>

# Check component logs
oc logs -n redhat-ods-applications <pod-name>

# Check events
oc get events -n redhat-ods-applications --sort-by='.lastTimestamp'
```

### Dashboard Not Accessible

```bash
# Verify route exists
oc get route rhods-dashboard -n redhat-ods-applications

# Check pod status
oc get pods -n redhat-ods-applications -l app=rhods-dashboard

# Check service
oc get svc rhods-dashboard -n redhat-ods-applications
```

## Common Workflows

### Create a Jupyter Workbench

1. Access RHODS Dashboard
2. Navigate to "Data Science Projects"
3. Create a new project
4. Add a workbench with desired notebook image
5. Configure resources (CPU, Memory, GPU)
6. Start workbench and access Jupyter

### Deploy a Model

1. Train model in Jupyter notebook
2. Save model to S3 or PVC
3. Create InferenceService or use ModelMesh
4. Configure serving runtime
5. Test inference endpoint

### Create a Pipeline

1. Access Data Science Pipelines UI
2. Design pipeline using visual editor or SDK
3. Define pipeline steps and dependencies
4. Upload and run pipeline
5. Monitor execution and artifacts

## Resource Requirements

OpenShift AI is resource-intensive. Recommended minimum:

- **CPU**: 8 cores available for workloads
- **Memory**: 32 GB available
- **Storage**: 100 GB for images and models
- **GPU** (optional): NVIDIA GPUs for training/serving

## Integration

### Git Integration
- Clone repositories in notebooks
- Push changes back to Git
- Use GitOps for pipeline definitions

### S3 Storage
- Store training data
- Save model artifacts
- Pipeline artifact storage

### Monitoring
- Prometheus metrics for all components
- Grafana dashboards included
- Custom metrics for models

## Resources

- [Red Hat OpenShift AI Documentation](https://access.redhat.com/documentation/en-us/red_hat_openshift_ai/)
- [Open Data Hub (upstream project)](https://opendatahub.io/)
- [KServe Documentation](https://kserve.github.io/website/)
- [Kubeflow Pipelines](https://www.kubeflow.org/docs/components/pipelines/)

## Notes

- **Sync Wave**: DataScienceCluster uses sync wave 10 to ensure operator CRDs are available
- **GitOps Friendly**: Ignores component managementState and status fields
- **Cluster-wide Operator**: Deployed in `openshift-operators` namespace
- **Multiple Namespaces**: Creates `redhat-ods-applications`, `redhat-ods-monitoring`, and other namespaces automatically
- **GPU Support**: Requires NVIDIA GPU Operator for GPU-accelerated workloads
