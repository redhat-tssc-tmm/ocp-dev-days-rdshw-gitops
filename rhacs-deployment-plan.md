# RHACS Deployment Plan — ArgoCD App-of-Apps

## Overview

Deploy RHACS (Red Hat Advanced Cluster Security) 4.11 as a new component in the existing ArgoCD app-of-apps, with:
- Central + SecuredCluster (this cluster)
- OpenShift Console integration plugin
- Cluster TLS certificate for the ACS console (no browser security warnings)
- SSO authentication via the existing `sso` Keycloak realm
- Admin role mapping for `admin@demo.redhat.com`

## Key Facts

| Item | Value |
|------|-------|
| RHACS operator CSV | `rhacs-operator.v4.11.4` (stable channel) |
| Catalog source | `redhat-operators-snapshot` |
| Cluster subdomain | `apps.cluster-5l9zg.dyn.redhatworkshops.io` |
| Keycloak route | `sso.apps.cluster-5l9zg.dyn.redhatworkshops.io` |
| Keycloak CRDs available | `Keycloak`, `KeycloakRealmImport` only (no `KeycloakClient`) |
| Registration method | CRS (Cluster Registration Secret) — replaces deprecated init-bundles |

## Design Decisions

### CRS Instead of Init-Bundles
Init-bundles are deprecated in RHACS 4.11. CRS (GA since 4.10) uses short-lived tokens and fixes the cluster ID mismatch that breaks the OpenShift Console integration. Still requires a Job to call the Central API, but the secured cluster negotiates its own identity.

### Job-Based Keycloak Client Creation
The `KeycloakRealmImport` operator is one-shot (`--override=false`, hardcoded). Modifying the CR after the realm exists has no effect. The only way to add a client to an existing realm is via the Keycloak Admin REST API. See `open-questions.md` for details.

### Client Secret via Vault
Follows the existing pattern: value defined in Vault KV store → ExternalSecret → K8s Secret. The SSO config Job reads the secret and uses it to create the Keycloak client with a predefined secret (no need to retrieve it after creation).

### Keycloak Admin Credentials
The SSO config Job reads the `keycloak-initial-admin` secret directly from the `keycloak` namespace. See `open-questions.md` item 2 for a future alternative via Vault.

## Component Structure

```
cluster/rhacs/
  Chart.yaml                        # umbrella chart with subchart dependencies
  values.yaml                       # defaults

  rhacs-operator/                   # subchart: operator installation
    Chart.yaml
    values.yaml
    templates/
      _helpers.tpl
      namespace.yaml                # rhacs-operator namespace
      operator-group.yaml
      subscription.yaml             # stable channel, snapshot catalog

  rhacs-central/                    # subchart: Central + TLS
    Chart.yaml
    values.yaml
    templates/
      _helpers.tpl
      namespace.yaml                # rhacs namespace
      job-copy-tls-cert.yaml        # copies ingress cert → central-default-tls-cert
      central-cr.yaml               # Central CR: route + consolePlugin + defaultTLSSecret

  rhacs-secured-cluster/            # subchart: CRS + SecuredCluster
    Chart.yaml
    values.yaml
    templates/
      _helpers.tpl
      job-crs.yaml                  # POST /v1/cluster-init/crs, applies secrets
      secured-cluster-cr.yaml       # centralEndpoint: central.rhacs.svc:443

  rhacs-sso-config/                 # subchart: Keycloak + RHACS OIDC
    Chart.yaml
    values.yaml
    templates/
      _helpers.tpl
      es-rhacs-sso-secret.yaml      # ExternalSecret → K8s Secret with client secret
      job-sso-config.yaml           # creates KC client, RHACS auth provider, role mappings
```

## Sync Wave Ordering

| Wave | Subchart | Resources |
|------|----------|-----------|
| -2 | `rhacs-operator` | Namespace, OperatorGroup, Subscription |
| 0 | `rhacs-central` | RHACS namespace, TLS cert copy Job, Central CR (route + consolePlugin + TLS) |
| 2 | `rhacs-secured-cluster` | CRS generation Job (waits for Central API, skips if already registered), SecuredCluster CR |
| 3 | `rhacs-sso-config` | ExternalSecret for client secret, SSO config Job |

## Central CR

```yaml
apiVersion: platform.stackrox.io/v1alpha1
kind: Central
metadata:
  name: stackrox-central-services
  namespace: rhacs
spec:
  central:
    exposure:
      route:
        enabled: true
    defaultTLSSecret:
      name: central-default-tls-cert
  consolePlugin:
    enabled: true
```

Note: `consolePlugin` field to be verified after operator install via `oc explain central.spec`.

## SecuredCluster CR

```yaml
apiVersion: platform.stackrox.io/v1alpha1
kind: SecuredCluster
metadata:
  name: stackrox-secured-cluster-services
  namespace: rhacs
spec:
  clusterName: local-secured-cluster
  centralEndpoint: central.rhacs.svc:443
```

## SSO Config Job Logic

1. Read RHACS client secret from K8s Secret (populated by ExternalSecret from Vault)
2. Get Keycloak admin token from `keycloak-initial-admin` secret in `keycloak` namespace
3. Create `rhacs` OIDC client in `sso` realm with the predefined secret (skip if exists)
4. Configure client scopes (offline_access as optional, standard defaults)
5. Assign `offline_access` role to `admin@demo.redhat.com`
6. Get RHACS admin password from `central-htpasswd` secret
7. Create OIDC auth provider "Keycloak SSO" in RHACS Central (skip if exists)
8. Map `admin@demo.redhat.com` → RHACS `Admin` role
9. Set default role `None` for unmatched users

All operations are idempotent (existence checks before creation).

## Files Modified in Existing Charts

### cluster/app-of-apps/values.yaml
New section:
```yaml
rhacs:
  enabled: true
  name: rhacs
  namespace: rhacs
  operatorNamespace: rhacs-operator
  clusterName: local-secured-cluster
```

### cluster/app-of-apps/templates/rhacs.yaml
New ArgoCD Application template (gated by `rhacs.enabled`), passes:
- Operator catalog source
- Cluster subdomain
- Keycloak host/realm

### cluster/vault/values.yaml
Add to secrets:
```yaml
  rhacs:
    clientId: rhacs
    clientSecret: ""
```

### cluster/vault/templates/cm-vault-setup.yaml
New Vault KV entry:
```yaml
- 'vault kv put kv/secrets/rhacs/client-secret clientId={{ $.Values.secrets.rhacs.clientId }} clientSecret={{ $.Values.secrets.rhacs.clientSecret }}'
```

### cluster/app-of-apps/templates/vault.yaml
Pass RHACS secret values through to the vault chart.

### Ansible automation (placeholders only)
Comments in `app-of-apps-application.yaml.j2` showing where to add RHACS values.
