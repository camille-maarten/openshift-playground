# Keycloak / Red Hat Single Sign-On (RHSSO) Operator

This directory contains the GitOps manifests for deploying the Red Hat Single Sign-On (RHSSO) operator, which is based on Keycloak - an open-source Identity and Access Management solution.

## Overview

The RHSSO operator provides:
- Identity and Access Management (IAM)
- Single Sign-On (SSO) capabilities
- User federation (LDAP, Active Directory, etc.)
- Identity brokering (external IdPs like Google, GitHub, etc.)
- Social login support
- Multi-factor authentication (MFA)
- Fine-grained authorization
- OpenID Connect (OIDC) and SAML 2.0 support

## Architecture

```
assets/1_gitops/keycloak/
├── manifests/
│   ├── 01-namespace.yaml          # Creates 'keycloak' namespace
│   ├── 02-operatorgroup.yaml      # Operator group for managing the namespace
│   └── 03-subscription.yaml       # Subscription to rhsso-operator from Red Hat catalog
└── README.md                       # This file
```

## Deployment via ArgoCD

The operator is deployed through ArgoCD using the application manifest:
- `assets/1_gitops/apps/11-keycloak.yaml`

### Deployment Steps

1. The manifests are deployed in order:
   - Namespace creation
   - OperatorGroup setup
   - Subscription to the operator

2. The operator automatically installs in the `keycloak` namespace

3. ArgoCD monitors and syncs changes automatically

## Post-Installation Configuration

After the operator is installed, you can create Keycloak instances using custom resources.

### Create a Keycloak Instance

Create a basic Keycloak instance:

```yaml
apiVersion: keycloak.org/v1alpha1
kind: Keycloak
metadata:
  name: keycloak-instance
  namespace: keycloak
  labels:
    app: keycloak
spec:
  instances: 1
  externalAccess:
    enabled: true
```

Apply this manifest:
```bash
oc apply -f keycloak-instance.yaml
```

### Access the Keycloak Admin Console

1. Get the Keycloak route:
```bash
oc get routes -n keycloak
```

2. Get the admin credentials:
```bash
# Username is 'admin'
# Get the password:
oc get secret credential-keycloak-instance -n keycloak -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d
```

3. Access the admin console:
```bash
# Get the URL
KEYCLOAK_URL=$(oc get route keycloak -n keycloak -o jsonpath='https://{.spec.host}')
echo "Keycloak Admin Console: $KEYCLOAK_URL/auth/admin"
```

## Common Use Cases

### 1. Integrate with OpenShift OAuth

Keycloak can be configured as an OpenID Connect identity provider for OpenShift:

```yaml
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: keycloak
    mappingMethod: claim
    type: OpenID
    openID:
      clientID: openshift
      clientSecret:
        name: keycloak-client-secret
      issuer: https://keycloak-route/auth/realms/master
      claims:
        preferredUsername:
        - preferred_username
        name:
        - name
        email:
        - email
```

### 2. Create a Realm for Applications

Realms are logical boundaries for managing users and applications:

```yaml
apiVersion: keycloak.org/v1alpha1
kind: KeycloakRealm
metadata:
  name: application-realm
  namespace: keycloak
spec:
  realm:
    id: application
    realm: application
    enabled: true
    displayName: "Application Realm"
  instanceSelector:
    matchLabels:
      app: keycloak
```

### 3. Create a Client for an Application

Clients represent applications that can request authentication:

```yaml
apiVersion: keycloak.org/v1alpha1
kind: KeycloakClient
metadata:
  name: my-app-client
  namespace: keycloak
spec:
  realmSelector:
    matchLabels:
      app: keycloak
  client:
    clientId: my-app
    name: My Application
    description: "My application client"
    protocol: openid-connect
    publicClient: false
    directAccessGrantsEnabled: true
    standardFlowEnabled: true
    serviceAccountsEnabled: true
    redirectUris:
      - "https://my-app.apps.cluster.example.com/*"
    webOrigins:
      - "https://my-app.apps.cluster.example.com"
```

## Verification

Check the operator installation:

```bash
# Check operator pod
oc get pods -n keycloak

# Check operator logs
oc logs -n keycloak -l name=rhsso-operator

# Check subscription status
oc get subscription rhsso-operator -n keycloak

# Check installed CSV (ClusterServiceVersion)
oc get csv -n keycloak
```

## Monitoring and Troubleshooting

### Check Keycloak Instance Status

```bash
oc get keycloak -n keycloak
oc describe keycloak keycloak-instance -n keycloak
```

### View Keycloak Logs

```bash
oc logs -n keycloak -l app=keycloak
```

### Common Issues

1. **Operator not starting**
   - Check events: `oc get events -n keycloak`
   - Verify subscription: `oc get subscription rhsso-operator -n keycloak -o yaml`

2. **Keycloak instance not creating**
   - Check operator logs: `oc logs -n keycloak -l name=rhsso-operator`
   - Verify CR status: `oc describe keycloak keycloak-instance -n keycloak`

3. **Cannot access admin console**
   - Verify route exists: `oc get routes -n keycloak`
   - Check pod status: `oc get pods -n keycloak`
   - Review pod logs: `oc logs -n keycloak -l app=keycloak`

## Database Configuration

By default, Keycloak uses an H2 database (not suitable for production). For production use, configure an external database:

```yaml
apiVersion: keycloak.org/v1alpha1
kind: Keycloak
metadata:
  name: keycloak-instance
  namespace: keycloak
spec:
  instances: 2
  externalAccess:
    enabled: true
  externalDatabase:
    enabled: true
  postgresDeploymentSpec:
    database:
      name: keycloak
      user: keycloak
      size: 10Gi
```

## Security Considerations

1. **Change Default Admin Credentials**: Always change the default admin password after installation
2. **Use TLS**: Ensure routes use HTTPS (OpenShift provides this by default)
3. **External Database**: Use a production-grade database for production deployments
4. **Backup**: Regularly backup Keycloak configuration and database
5. **Resource Limits**: Set appropriate resource limits for production workloads

## Resources

- [Red Hat Single Sign-On Documentation](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [RHSSO Operator Guide](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/7.6/html/server_installation_and_configuration_guide/operator)

## Version Information

The operator version is tracked in:
- `info/versions.txt` - Human-readable format with timestamps
- `info/versions.csv` - CSV format for automated processing

To check the current version:
```bash
oc get csv -n keycloak -o jsonpath='{.items[*].spec.displayName}{" - "}{.items[*].spec.version}'
```
