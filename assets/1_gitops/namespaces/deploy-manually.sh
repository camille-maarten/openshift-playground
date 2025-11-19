#!/bin/bash

# Manual Playground Namespaces Deployment Script
# This script deploys playground namespace resources in the correct order
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
MANIFEST_PATH="namespaces/manifests"

echo "================================================"
echo "  Manual Playground Namespaces Deployment"
echo "================================================"
echo ""

# Wave -1: ArgoCD RBAC (if using ArgoCD)
echo "Step 0: Setting up ArgoCD RBAC permissions..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/00-argocd-rbac.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ ArgoCD RBAC configured"
echo ""

# Wave 0: Namespace
echo "Step 1: Creating namespace..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/01-playground-namespace.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ Namespace created"
echo ""

# Wave 1: ResourceQuota and LimitRange
echo "Step 2: Creating resource quotas and limits..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/02-playground-resourcequota.yaml" -u "admin:gitea1234!" | oc apply -f -
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/03-playground-limitrange.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ Resource quotas and limits configured"
echo ""

# Wave 2: NetworkPolicies
echo "Step 3: Creating network policies..."
curl -k -s "${GITEA_URL}/api/v1/repos/${REPO_PATH}/raw/${MANIFEST_PATH}/04-playground-networkpolicies.yaml" -u "admin:gitea1234!" | oc apply -f -
echo "✓ Network policies configured"
echo ""

echo "================================================"
echo "  Deployment Complete!"
echo "================================================"
echo ""
echo "Verify the deployment:"
echo "  oc get all -n playground"
echo ""
echo "Check resource quota:"
echo "  oc get resourcequota -n playground"
echo ""
echo "Check limit ranges:"
echo "  oc get limitrange -n playground"
echo ""
echo "Check network policies:"
echo "  oc get networkpolicy -n playground"
echo ""
