# Keycloak Integration with Red Hat Developer Hub

This document describes the integration between Keycloak (Red Hat Single Sign-On) and Red Hat Developer Hub (RHDH) for authentication via OpenID Connect (OIDC).

## Overview

The integration provides:
- **Single Sign-On (SSO)**: Users authenticate once with Keycloak and gain access to Developer Hub
- **Centralized User Management**: All users are managed in Keycloak
- **OIDC Protocol**: Standards-based authentication using OpenID Connect
- **Secure Token Exchange**: JWT tokens for authenticated sessions

## Architecture

```
┌──────────────┐         ┌─────────────┐         ┌──────────────┐
│   Browser    │  OIDC   │  Keycloak   │  OIDC   │     RHDH     │
│              │◄────────┤   (IdP)     ├────────►│  (Backend)   │
│              │         │             │         │              │
└──────────────┘         └─────────────┘         └──────────────┘
       │                        │                        │
       │   1. Redirect to       │                        │
       │      Keycloak          │                        │
       ├───────────────────────►│                        │
       │                        │                        │
       │   2. User Login        │                        │
       ├───────────────────────►│                        │
       │                        │                        │
       │   3. Authorization     │                        │
       │      Code              │                        │
       │◄───────────────────────┤                        │
       │                        │                        │
       │   4. Auth Code         │                        │
       ├────────────────────────┼───────────────────────►│
       │                        │                        │
       │                        │   5. Token Exchange    │
       │                        │◄───────────────────────┤
       │                        │                        │
       │                        │   6. ID/Access Token   │
       │                        ├───────────────────────►│
       │                        │                        │
       │   7. RHDH Session      │                        │
       │◄───────────────────────┴────────────────────────┤
       │                                                 │
```

## GitOps Components

### Keycloak Resources

Located in: `assets/1_gitops/keycloak/manifests/`

1. **01-namespace.yaml** - Creates `keycloak` namespace
2. **02-operatorgroup.yaml** - OperatorGroup for Keycloak operator
3. **03-subscription.yaml** - Subscription to RHSSO operator
4. **04-keycloak-instance.yaml** - Keycloak server instance
5. **05-realm-rhdh.yaml** - Keycloak realm named `rhdh`
6. **06-client-rhdh.yaml** - OIDC client configuration for RHDH
7. **07-user-pe.yaml** - User `pe-user` with credentials

### Developer Hub Resources

Located in: `assets/1_gitops/developerhub/manifests/`

Modified files:
- **04-app-config-configmap.yaml** - Added OIDC auth configuration
- **06-secrets.yaml** - Added Keycloak client credentials

## Configuration Details

### Keycloak Realm Configuration

**Realm Name**: `rhdh`

**Settings**:
- Registration: Disabled (users must be created by admin)
- Login with email: Enabled
- Reset password: Enabled
- Brute force protection: Enabled
- Session timeout: 30 minutes (idle), 10 hours (max)
- Access token lifespan: 5 minutes

### Keycloak Client Configuration

**Client ID**: `rhdh`

**Client Type**: Confidential (uses client secret)

**Protocol**: `openid-connect`

**Flows Enabled**:
- Standard Flow: Yes (Authorization Code Flow)
- Direct Access Grants: Yes
- Implicit Flow: No
- Service Accounts: No

**Redirect URIs**:
- `https://backstage-developer-hub-rhdh.apps-crc.testing/*`
- `https://backstage-developer-hub-rhdh.apps-crc.testing/api/auth/oidc/handler/frame`

**Default Client Scopes**:
- `profile` - User profile information
- `email` - User email address
- `roles` - User roles

**Protocol Mappers**:
- `username` → `preferred_username` claim
- `email` → `email` claim
- `full name` → `name` claim

### Developer Hub Authentication Configuration

**Provider**: OIDC (OpenID Connect)

**Metadata URL**:
```
${KEYCLOAK_BASE_URL}/realms/rhdh/.well-known/openid-configuration
```

**Client Credentials**:
- Client ID: `rhdh`
- Client Secret: Stored in `rhdh-secrets` Secret

**Sign-In Resolver**: `preferredUsernameMatchingUserEntityName`
- Maps the Keycloak username to the Backstage user entity

## Pre-configured Users

### pe-user

- **Username**: `pe-user`
- **Password**: `rhdh1234!`
- **First Name**: Platform
- **Last Name**: Engineer
- **Email**: pe-user@example.com
- **Email Verified**: Yes

## Deployment Steps

### 1. Deploy Keycloak

```bash
cd assets/1_gitops
./upload-and-deploy.sh
```

### 2. Wait for Keycloak to be Ready

```bash
# Check Keycloak operator
oc get pods -n keycloak

# Wait for Keycloak instance
oc get keycloak -n keycloak
oc wait --for=condition=ready keycloak/keycloak -n keycloak --timeout=300s
```

### 3. Verify Keycloak Resources

```bash
# Check realm
oc get keycloakrealm -n keycloak

# Check client
oc get keycloakclient -n keycloak

# Check user
oc get keycloakuser -n keycloak
```

### 4. Get Keycloak Route

```bash
KEYCLOAK_ROUTE=$(oc get route keycloak -n keycloak -o jsonpath='{.spec.host}')
echo "Keycloak URL: https://$KEYCLOAK_ROUTE"
```

### 5. Update Developer Hub Configuration

The deploy script should automatically update the Developer Hub configuration with the correct Keycloak URL. If manual update is needed:

```bash
# Update the secret with the actual Keycloak route
oc patch secret rhdh-secrets -n rhdh --type='json' -p="[
  {\"op\": \"replace\", \"path\": \"/data/KEYCLOAK_BASE_URL\", \"value\": \"$(echo -n https://$KEYCLOAK_ROUTE | base64)\"}
]"

# Restart Developer Hub
oc rollout restart deployment backstage-developer-hub -n rhdh
```

### 6. Access Developer Hub

```bash
RHDH_ROUTE=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}')
echo "Developer Hub URL: https://$RHDH_ROUTE"
```

## Testing the Integration

### 1. Access Developer Hub

Navigate to the Developer Hub URL in your browser.

### 2. Login with Keycloak

You should be redirected to the Keycloak login page.

### 3. Authenticate

Use the pre-configured user credentials:
- **Username**: `pe-user`
- **Password**: `rhdh1234!`

### 4. Verify Access

After successful authentication, you should be redirected back to Developer Hub and logged in as `pe-user`.

## Troubleshooting

### Login Fails with "Invalid Redirect URI"

**Issue**: Keycloak rejects the redirect because the URI doesn't match the configured redirect URIs.

**Solution**:
1. Get the actual RHDH route:
   ```bash
   RHDH_ROUTE=$(oc get route -n rhdh -o jsonpath='{.items[0].spec.host}')
   ```

2. Update the Keycloak client redirect URIs manually or update the manifest and redeploy.

### "OIDC Provider Not Found" Error

**Issue**: Developer Hub cannot reach Keycloak or the OIDC metadata URL is incorrect.

**Solution**:
1. Verify Keycloak is running:
   ```bash
   oc get pods -n keycloak
   ```

2. Check the KEYCLOAK_BASE_URL in the secret:
   ```bash
   oc get secret rhdh-secrets -n rhdh -o jsonpath='{.data.KEYCLOAK_BASE_URL}' | base64 -d
   ```

3. Test the metadata URL:
   ```bash
   curl -k https://$KEYCLOAK_ROUTE/realms/rhdh/.well-known/openid-configuration
   ```

### "Invalid Client" or "Unauthorized Client"

**Issue**: Client secret mismatch or client not found in Keycloak.

**Solution**:
1. Verify the client exists:
   ```bash
   oc get keycloakclient rhdh-client -n keycloak
   ```

2. Get the client secret from Keycloak admin console or create a new one.

3. Update the RHDH secret:
   ```bash
   oc patch secret rhdh-secrets -n rhdh --type='json' -p="[
     {\"op\": \"replace\", \"path\": \"/data/KEYCLOAK_CLIENT_SECRET\", \"value\": \"$(echo -n 'new-secret' | base64)\"}
   ]"
   ```

### User Cannot Login - "Invalid Username or Password"

**Issue**: User doesn't exist or password is incorrect.

**Solution**:
1. Verify the user exists:
   ```bash
   oc get keycloakuser pe-user -n keycloak
   ```

2. Check the user details:
   ```bash
   oc get keycloakuser pe-user -n keycloak -o yaml
   ```

3. If needed, delete and recreate the user:
   ```bash
   oc delete keycloakuser pe-user -n keycloak
   # Wait a moment, then ArgoCD will recreate it
   ```

### Session Expires Too Quickly

**Issue**: Users are logged out frequently.

**Solution**:
Update the realm session settings in `05-realm-rhdh.yaml`:
```yaml
ssoSessionIdleTimeout: 3600  # 1 hour
ssoSessionMaxLifespan: 86400  # 24 hours
```

## Adding New Users

### Via GitOps (Recommended)

Create a new user manifest:

```yaml
apiVersion: keycloak.org/v1alpha1
kind: KeycloakUser
metadata:
  name: new-user
  namespace: keycloak
spec:
  realmSelector:
    matchLabels:
      app: keycloak
      realm: rhdh
  user:
    username: "new-user"
    firstName: "New"
    lastName: "User"
    email: "new-user@example.com"
    enabled: true
    emailVerified: true
    credentials:
      - type: "password"
        value: "secure-password"
        temporary: false
```

### Via Keycloak Admin Console

1. Access the Keycloak admin console:
   ```bash
   KEYCLOAK_ROUTE=$(oc get route keycloak -n keycloak -o jsonpath='{.spec.host}')
   echo "Keycloak Admin URL: https://$KEYCLOAK_ROUTE/auth/admin"
   ```

2. Get admin credentials:
   ```bash
   oc get secret credential-keycloak -n keycloak -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d
   ```

3. Navigate to the `rhdh` realm

4. Click "Users" → "Add user"

5. Fill in user details and save

6. Go to "Credentials" tab and set password

## Security Considerations

### Client Secret Rotation

Periodically rotate the client secret:

1. Generate a new secret in Keycloak
2. Update the RHDH secret:
   ```bash
   oc create secret generic rhdh-secrets \
     --from-literal=KEYCLOAK_CLIENT_SECRET='new-secret' \
     -n rhdh --dry-run=client -o yaml | oc apply -f -
   ```
3. Restart RHDH

### Password Policies

Configure password policies in Keycloak:
- Minimum length: 8 characters
- Require uppercase letters
- Require lowercase letters
- Require digits
- Require special characters
- Password history: 5
- Password expiration: 90 days

### TLS/SSL

Ensure all communication uses HTTPS:
- Keycloak route should use edge or reencrypt TLS
- RHDH route should use edge or reencrypt TLS
- Never use HTTP for authentication traffic

## Advanced Configuration

### Custom Claims

Add custom user attributes as claims by creating protocol mappers in the client configuration.

### Role Mapping

Map Keycloak roles to RHDH permissions by:
1. Creating roles in Keycloak realm
2. Assigning roles to users
3. Configuring role mappers in the client
4. Using role-based access control in RHDH

### Multi-Factor Authentication

Enable MFA in the Keycloak realm:
1. Configure OTP policy
2. Set required actions for users
3. Users will be prompted to configure MFA on first login

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Red Hat Single Sign-On Documentation](https://access.redhat.com/documentation/en-us/red_hat_single_sign-on/)
- [Backstage Authentication Documentation](https://backstage.io/docs/auth/)
- [OIDC Specification](https://openid.net/specs/openid-connect-core-1_0.html)
