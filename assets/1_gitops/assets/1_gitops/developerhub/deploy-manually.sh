#!/bin/bash

# Manual Developer Hub Deployment Script
# This script deploys Developer Hub resources in the correct order
# Use this if ArgoCD automated sync is not working

set -e

# Get Gitea URL from route
echo "Retrieving Gitea URL from cluster..."
GITEA_URL=$(oc get route gitea -n gitea -o jsonpath='https://{.spec.host}')
if [ -z "$GITEA_URL" ]; then
  echo "✗ Error: Could not retrieve Gitea route. Is Gitea installed?"
  echo "  Check with: oc get route gitea -n gitea"
  exit 1
fi
echo "✓ Using Gitea URL: ${GITEA_URL}"
echo ""

REPO_PATH="admin/playground-gitops"
MANIFEST_PATH="developerhub/manifests"

echo "================================================"
echo "  Manual Developer Hub Deployment"
echo "================================================"
echo ""

# Wave -1: ArgoCD RBAC (if using ArgoCD)
echo "Step 0: Setting up ArgoCD RBAC permissions..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/00-argocd-rbac.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ ArgoCD RBAC configured"
echo ""

# Wave 0: Namespace and OperatorGroup
echo "Step 1: Creating namespace and operator group..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/01-namespace.yaml" -u "admin:gitea1234!" | oc apply -f -
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/02-operatorgroup.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ Namespace and OperatorGroup created"
echo ""

# Wave 1: Subscription (Operator)
echo "Step 2: Installing RHDH operator..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/03-subscription.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ Operator subscription created"
echo ""

# Wait for operator to be ready
echo "Step 3: Waiting for RHDH operator to be ready (this may take 2-3 minutes)..."
echo "Checking for Backstage CRD..."
for i in {1..60}; do
  if oc get crd backstages.rhdh.redhat.com &> /dev/null; then
    echo "✓ Backstage CRD is available"
    break
  fi
  if [ $i -eq 60 ]; then
    echo "✗ Timeout waiting for Backstage CRD"
    echo "Check operator status: oc get csv -n rhdh"
    exit 1
  fi
  echo -n "."
  sleep 5
done
echo ""

# Wave 3: ConfigMaps, Secrets, PostgreSQL
echo "Step 4: Creating configuration resources..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/04-app-config-configmap.yaml" -u "admin:gitea1234!" | oc apply -f -
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/05-rbac-policy-configmap.yaml" -u "admin:gitea1234!" | oc apply -f -
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/06-secrets.yaml" -u "admin:gitea1234!" | oc apply -f -
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/07-postgres-deployment.yaml" -u "admin:gitea1234!" | oc apply -f -
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/09-dynamic-plugins-configmap.yaml" -u "admin:gitea1234!" | oc apply -f -
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/10-rbac-groups.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ Configuration resources created"
echo ""

# Wait for PostgreSQL to be ready
echo "Step 5: Waiting for PostgreSQL to be ready..."
oc wait --for=condition=available --timeout=300s deployment/postgres -n rhdh || echo "Warning: PostgreSQL may not be fully ready"
echo ""

# Wave 2: Backstage Instance
echo "Step 6: Creating Backstage instance..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/08-backstage-instance.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ Backstage instance created"
echo ""

echo "================================================"
echo "  Deployment Complete!"
echo "================================================"
echo ""
echo "Monitor the deployment:"
echo "  oc get pods -n rhdh -w"
echo ""
echo "Get the Developer Hub URL:"
echo "  oc get route -n rhdh"
echo ""
echo "Check Backstage status:"
echo "  oc get backstage developer-hub -n rhdh"
echo ""
