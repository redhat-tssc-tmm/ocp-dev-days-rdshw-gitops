# Open Questions

## 1. KeycloakRealmImport Origin

The `KeycloakRealmImport` CR (`sso` in namespace `keycloak`) is **not** in either the gitops or automation repos. It is created by an upstream AgnosticD workload role (`ocp4_workload_authentication`), which:

- Deploys the Keycloak operator (RHBK) and Keycloak CR
- Creates the `sso` realm via `KeycloakRealmImport` containing all three clients (`idp-4-ocp`, `backstage`, `backstage-plugin`), users, roles, and groups
- Exposes client secrets as Ansible facts (e.g., `ocp4_workload_authentication_keycloak_backstage_client_secret`)

The workshop automation role (`ocp4_workload_dev_days_rdshw_cluster_bootstrap`) consumes these facts and passes the client secrets through to Vault for use by Developer Hub.

**Future consideration:** If we need to add more Keycloak clients (like `rhacs`), the ideal approach would be to include them in the upstream `KeycloakRealmImport` before the realm is first created. However:

- The `KeycloakRealmImport` operator is **one-shot**: it creates a Job on CR creation and never reconciles changes. Editing the CR after initial import has no effect.
- The Job uses `--override=false` (hardcoded, not configurable). Since the realm already exists, the entire import is skipped — all-or-nothing at the realm level.
- Deleting and recreating the Job still skips because the realm exists. The only way to re-import would be to delete the realm first (destructive — loses sessions, tokens, runtime state).
- Deleting the CR only cleans up the K8s Job/Pod; the realm persists in Keycloak.

**Conclusion:** Adding clients to an existing realm must be done via the Keycloak Admin REST API (Job-based approach). For future deployments, new clients should be added to the upstream `KeycloakRealmImport` in `ocp4_workload_authentication` so they are included in the initial one-shot import.

## 2. Keycloak Admin Credentials via Vault

Currently, the SSO configuration Job reads the `keycloak-initial-admin` secret directly from the `keycloak` namespace. This works because the Keycloak operator always creates this secret, but it couples the Job to the operator's internal convention.

**Future consideration:** Pass the Keycloak admin credentials through the Ansible automation into Vault (matching how backstage client secrets flow: upstream Ansible role → workshop Ansible role → app-of-apps values → Vault KV → ExternalSecret). This would require the upstream `ocp4_workload_authentication` role to expose the admin password as an Ansible fact and the workshop role to forward it. This decouples the RHACS deployment from the Keycloak operator's secret naming convention and makes it work consistently in standalone gitops mode with credentials supplied via values.
