# Keycloak / Red Hat Build of Keycloak (RHBK) Operator

This directory contains the GitOps manifests for deploying the Red Hat Build of Keycloak (RHBK) operator, which is Red Hat's supported distribution of Keycloak - an open-source Identity and Access Management solution.

## Overview

The RHBK operator provides:
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
│   ├── 01-namespace.yaml                # Creates 'keycloak' namespace
│   ├── 02-operatorgroup.yaml            # Operator group for managing the namespace
│   ├── 02-rolebinding.yaml              # ArgoCD RBAC permissions
│   ├── 03-subscription.yaml             # Subscription to rhbk-operator from Red Hat catalog
│   ├── 03-postgres-deployment.yaml      # PostgreSQL database for Keycloak
│   ├── 03-keycloak-db-secret.yaml       # Database credentials
│   ├── 04-keycloak-instance.yaml        # Keycloak instance (v2alpha1)
│   └── 05-realm-import-rhdh.yaml        # Realm configuration with clients and users
└── README.md                             # This file
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

Create a basic Keycloak instance using RHBK v2alpha1 API:

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  instances: 1
  db:
    vendor: postgres
    host: postgres
    usernameSecret:
      name: keycloak-db-secret
      key: username
    passwordSecret:
      name: keycloak-db-secret
      key: password
  ingress:
    enabled: true
  http:
    httpEnabled: true
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
# Get the password - RHBK stores it in a different secret
oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d
```

3. Access the admin console:
```bash
# Get the URL
KEYCLOAK_URL=$(oc get route keycloak-ingress -n keycloak -o jsonpath='https://{.spec.host}')
echo "Keycloak Admin Console: $KEYCLOAK_URL/admin"
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

### 2. Import a Realm with Clients and Users

In RHBK v2alpha1, realms, clients, and users are managed using `KeycloakRealmImport`:

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: KeycloakRealmImport
metadata:
  name: application-realm-import
  namespace: keycloak
spec:
  keycloakCRName: keycloak
  realm:
    id: application
    realm: application
    enabled: true
    displayName: "Application Realm"
    clients:
      - clientId: my-app
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
    users:
      - username: myuser
        firstName: My
        lastName: User
        email: myuser@example.com
        enabled: true
        emailVerified: true
        credentials:
          - type: password
            value: mypassword
            temporary: false
```

## Verification

Check the operator installation:

```bash
# Check operator pod
oc get pods -n keycloak

# Check operator logs
oc logs -n keycloak -l app.kubernetes.io/name=rhbk-operator

# Check subscription status
oc get subscription rhbk-operator -n keycloak

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
   - Verify subscription: `oc get subscription rhbk-operator -n keycloak -o yaml`

2. **Keycloak instance not creating**
   - Check operator logs: `oc logs -n keycloak -l app.kubernetes.io/name=rhbk-operator`
   - Verify CR status: `oc describe keycloak keycloak -n keycloak`

3. **Cannot access admin console**
   - Verify route exists: `oc get routes -n keycloak`
   - Check pod status: `oc get pods -n keycloak`
   - Review pod logs: `oc logs -n keycloak -l app=keycloak`

## Database Configuration

RHBK v2alpha1 requires PostgreSQL database. The manifests include a PostgreSQL deployment for development. For production use, configure an external database:

```yaml
apiVersion: k8s.keycloak.org/v2alpha1
kind: Keycloak
metadata:
  name: keycloak
  namespace: keycloak
spec:
  instances: 2
  db:
    vendor: postgres
    host: your-postgres-host
    database: keycloak
    port: 5432
    usernameSecret:
      name: postgres-credentials
      key: username
    passwordSecret:
      name: postgres-credentials
      key: password
  ingress:
    enabled: true
```

## Security Considerations

1. **Change Default Admin Credentials**: Always change the default admin password after installation
2. **Use TLS**: Ensure routes use HTTPS (OpenShift provides this by default)
3. **External Database**: Use a production-grade database for production deployments
4. **Backup**: Regularly backup Keycloak configuration and database
5. **Resource Limits**: Set appropriate resource limits for production workloads

## Resources

- [Red Hat Build of Keycloak Documentation](https://access.redhat.com/documentation/en-us/red_hat_build_of_keycloak/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [RHBK Operator Guide](https://access.redhat.com/documentation/en-us/red_hat_build_of_keycloak/)

## Migration from RHSSO to RHBK

This deployment uses Red Hat Build of Keycloak (RHBK) v2alpha1 API, which replaces the older Red Hat Single Sign-On (RHSSO) v1alpha1 API.

### Key Differences Between RHSSO and RHBK

| Feature | RHSSO v1alpha1 | RHBK v2alpha1 |
|---------|----------------|---------------|
| API Group | keycloak.org | k8s.keycloak.org |
| Database | H2 (embedded) default | PostgreSQL required |
| Realm Management | Separate CRs (KeycloakRealm, KeycloakClient, KeycloakUser) | Unified KeycloakRealmImport CR |
| Ingress | Custom ingress config | Built-in OpenShift route support |
| Operator Channel | stable | stable-v24 |

### Migration Steps

If you have an existing RHSSO deployment, follow these steps to migrate to RHBK:

1. **Export existing realm configuration**:
```bash
# Access RHSSO admin console and export realm as JSON
# Or use the CLI export
oc exec -n keycloak deployment/keycloak -- /opt/keycloak/bin/kc.sh export \
  --dir /tmp/export --realm your-realm
```

2. **Deploy PostgreSQL database**:
```bash
oc apply -f manifests/03-postgres-deployment.yaml
oc apply -f manifests/03-keycloak-db-secret.yaml
```

3. **Update subscription to RHBK**:
```bash
oc apply -f manifests/03-subscription.yaml
```

4. **Create RHBK Keycloak instance**:
```bash
oc apply -f manifests/04-keycloak-instance.yaml
```

5. **Import realm using KeycloakRealmImport**:
```bash
# Convert old KeycloakRealm to KeycloakRealmImport format
# Apply the import
oc apply -f manifests/05-realm-import-rhdh.yaml
```

## SSO Integration with Red Hat Developer Hub

Keycloak is pre-configured to provide SSO authentication for Red Hat Developer Hub (RHDH).

### Configuration Overview

The SSO integration uses:
- **Protocol**: OpenID Connect (OIDC)
- **Realm**: `rhdh`
- **Client ID**: `rhdh`
- **Client Secret**: Auto-generated by Keycloak operator
- **User**: `pe-user` (password: `rhdh1234!`)

### Template Variables

The configuration uses template variables that are automatically replaced with actual cluster routes:

| Variable | Description | Example |
|----------|-------------|---------|
| `GITEA_URL` | Gitea base URL | `https://gitea-gitea.apps.cluster-xxx...` |
| `RHDH_BASE_URL` | Developer Hub base URL | `https://backstage-developer-hub-rhdh.apps.cluster-xxx...` |
| `KEYCLOAK_BASE_URL` | Keycloak base URL | `https://keycloak-ingress-keycloak.apps.cluster-xxx...` |

These variables are replaced by `update-keycloak-rhdh-config.sh` script after deployment.

### Manual SSO Configuration

If automatic configuration fails, configure SSO manually:

1. **Get route URLs**:
```bash
KEYCLOAK_ROUTE=$(oc get route keycloak-ingress -n keycloak -o jsonpath='{.spec.host}')
RHDH_ROUTE=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}')

echo "Keycloak: https://${KEYCLOAK_ROUTE}"
echo "RHDH: https://${RHDH_ROUTE}"
```

2. **Update KeycloakRealmImport redirect URIs**:
```bash
oc edit keycloakrealmimport rhdh-realm-import -n keycloak

# Update redirectUris to:
#   - "https://${RHDH_ROUTE}/*"
#   - "https://${RHDH_ROUTE}/api/auth/oidc/handler/frame"
```

3. **Update Developer Hub app-config**:
```bash
oc edit configmap app-config-rhdh -n rhdh

# Update:
#   app.baseUrl: https://${RHDH_ROUTE}
#   backend.baseUrl: https://${RHDH_ROUTE}
#   auth.providers.oidc.development.metadataUrl:
#     https://${KEYCLOAK_ROUTE}/realms/rhdh/.well-known/openid-configuration
```

4. **Update Developer Hub secrets**:
```bash
oc edit secret rhdh-secrets -n rhdh

# Update (base64 encoded):
#   KEYCLOAK_BASE_URL: https://${KEYCLOAK_ROUTE}
```

5. **Restart Developer Hub**:
```bash
oc rollout restart deployment/backstage-developer-hub -n rhdh
```

### Automated SSO Configuration

The `update-keycloak-rhdh-config.sh` script automates the SSO configuration:

```bash
cd assets/1_gitops
./update-keycloak-rhdh-config.sh
```

This script:
1. Gets Keycloak and RHDH routes from the cluster
2. Updates KeycloakRealmImport with correct redirect URIs
3. Updates Developer Hub ConfigMaps and Secrets
4. Commits and pushes changes to Gitea
5. Triggers ArgoCD sync for both applications

### Verifying SSO Integration

1. **Access Developer Hub**:
```bash
RHDH_URL=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}')
echo "https://${RHDH_URL}"
```

2. **Log in with Keycloak**:
   - Click "Sign in" on Developer Hub
   - You should be redirected to Keycloak
   - Enter credentials: `pe-user` / `rhdh1234!`
   - You should be redirected back to Developer Hub

3. **Check Keycloak admin console**:
```bash
KEYCLOAK_URL=$(oc get route keycloak-ingress -n keycloak -o jsonpath='{.spec.host}')
echo "https://${KEYCLOAK_URL}/admin"

# Get admin password
oc get secret keycloak-initial-admin -n keycloak -o jsonpath='{.data.password}' | base64 -d
```

## Version Information

The operator version is tracked in:
- `info/versions.txt` - Human-readable format with timestamps
- `info/versions.csv` - CSV format for automated processing

To check the current version:
```bash
oc get csv -n keycloak -o jsonpath='{.items[*].spec.displayName}{" - "}{.items[*].spec.version}'
```
