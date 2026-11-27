---
name: deploy-api
description: Deploy this API (and its service-cp-civil-caseingestion-case) end to end to dev (APIM sandbox) or SIT (APIM preview) — Entra, federation, APIM Terraform, release, cp-vp-aks-deploy, pipeline 434, the CJSCPPUID Key Vault mapping (pipeline 550) and the smoke test. Use whenever someone wants to deploy, promote or onboard the API to an environment, set up a new caller, or asks "how do we get this to dev/SIT", "which pipeline", "why 403 CALLER_NOT_ONBOARDED / BACKEND_FORBIDDEN", even if they don't say "skill".
---

# Deploy the API to dev or SIT

The API reaches callers through Azure API Management (APIM). APIM sends each call to the Spring Boot
service in AKS, and the service forwards it to the CP context (`cpp-context-staging-prosecutors-civil`).
Seven repositories own a piece of that path. This skill gives the order, the exact values and the checks
for **dev** and **SIT**, as done for CIMD-4175 (Nov 2026).

Full story, with every PR and the reasons: Confluence runbook
https://hmcts.atlassian.net/wiki/spaces/DATAIN/pages/391775615/CPCI-new-API-runbook

## Rules

- **Never** put a client secret, subscription key or token in a file, PR, chat or log. The person runs those
  commands in their own terminal. Client ids, tenant ids and CP user ids are identifiers. They're fine.
- Shared repos (`external-entra-id`, `azure-github-federation-config`, `cpp-terraform-federation-credentials`)
  hold other teams' config. Change one entry, open the PR, and let the owners review it. Don't self-merge.
- Read every Terraform plan before anything is applied. If it shows more than your change, stop and ask.
- Only the person can run Azure DevOps pipelines (434, 550) and approve applies. Give them the exact values.

## Environments

| | Dev | SIT |
| --- | --- | --- |
| Public URL | `https://sandbox.api.hmcts.net/amp/cpci/v1` | `https://sps-api-mgmt.preview.api.hmcts.net/amp/cpci/v1` |
| APIM instance / tfvars | `sps-api-mgmt-sbox` / `infrastructure/sbox.tfvars` | `sps-api-mgmt-preview` / `infrastructure/preview.tfvars` |
| Entra tenant | sbox `d44f885c-4fac-47bf-afde-d7d861ec4d7b` | stg `db827888-77df-4707-b3d9-24a3dfe32889` |
| API app (audience) | `amp-api-caseingestion` `6474e0e1-d2b3-4383-a7d0-5253c8dc9ff4` | `amp-api-cpci` `6ce2737c-86bc-4e5c-8399-e3986c598879` |
| Test caller `amp-test-external-client` | `378a2954-c99b-4f8d-a35b-e0e70ecd3ea5` | `e5b947ce-a761-4373-a437-2e21447d4808` |
| Enforcement caller `amp-enforcement-external-client` | – | `cfc4d419-ff0f-472e-859f-bce653826b84` (`app.read` on `amp-api-cpci` only) |
| APIM backend (`service_host`) | `devamp01-appgw.dev.nl.cjscp` | `sitamp01-appgw.sit.nl.cjscp` |
| Deploy branch / env file | `env/dev` / `services/service-cp-civil-caseingestion-case/dev.yml` | `env/sit` / `services/service-cp-civil-caseingestion-case/sit.yml` |
| Cluster / namespace | `K8-DEV-CS01-CL01` / `ns-dev-amp-01` | `K8-SIT-CS01-CL01` / `ns-sit-amp-01` |
| Pipeline 434 stack / cpbackendenv | `devamp01` / `steccm64` | `sitamp01` / `sitccm01` |
| Image | draft `0.0.0-<commit>_<time>` (merge to `main`) | release `X.Y.Z_<time>` (GitHub release) |
| CJSCPPUID vault / CP user | `KV-DEV-CCM-01` / `ac2ea2e7-a4ea-4151-ba21-dd8a0568dc97` | `KV-SIT-CCM-01` / `463b33a1-1dec-4d1c-ae55-07369f43451a` |

**APIM demo** (`infrastructure/demo.tfvars`, `https://sps-api-mgmt.demo.api.hmcts.net/amp/cpci/v1`) is also
registered and routes to SIT. It **doesn't connect to CP yet**, so SIT callers use **preview**. Demo is planned
to become the SIT entry point later. Keep `demo.tfvars` in step with `preview.tfvars`.

## Dev checklist

- [ ] 1. API repo merged to `main` → package `0.0.0-<commit>` published (Build and Publish DRAFT).
- [ ] 2. Service builds against it; merge to `main` → image tag from the **Wait-ACR-Copy** log line
      `Resolved real tag from ADO logs: …`.
- [ ] 3. `external-entra-id`, `tenants/sbox/config/apps.yaml`: the API app with role `app.read`, and the caller granted it.
- [ ] 4. `azure-github-federation-config`, `app-registrations.yaml`: the API repo's two subjects under **DTS AMp Sandbox**:
      `repo:hmcts@22817111/api-cp-civil-caseingestion-case@1461309431:pull_request` and `…:ref:refs/heads/main`.
- [ ] 5. API repo Actions variables `AZURE_CLIENT_ID_SBOX`, `AZURE_SUBSCRIPTION_SBOX`, `AZURE_SUBSCRIPTION_ID_SBOX`,
      `TFSTATE_STORAGE_ACCOUNT_NONPROD`. Copy them from `api-cp-crime-schedulingandlisting-courtschedule`
      (`gh variable get … | gh variable set …`). They aren't secrets.
- [ ] 6. `sbox.tfvars` → PR plan adds only → merge applies → `curl …/amp/cpci/v1/submissions/<uuid>` gives `401`.
- [ ] 7. `cp-vp-aks-deploy` PR into `env/dev`: name in `vp-config/apps_to_deploy`, block in
      `vp-config/services_values.yml`, `dev.yml` with `AUTH_*` and `PUBLIC_BASE_URL`.
- [ ] 8. Pipeline 434 (values below). Pod `2/2 Running`.
- [ ] 9. CJSCPPUID mapping for the caller (`vars/dev.tfvars`) + pipeline 550, as below.
- [ ] 10. Subscription key in the [sandbox portal](https://amp-portal.sandbox.api.hmcts.net), then the smoke test.

## SIT checklist (after dev works)

- [ ] 1. `external-entra-id`, `tenants/stg/config/apps.yaml`: the API app (in stg it's named `amp-api-cpci`, #70) and grant each caller.
      Renaming an app there recreates it with a **new client id**, so update `preview.tfvars`, `demo.tfvars` and `sit.yml` after.
      The ids are in Key Vault `kvspsextidaat` (`entra-app-<name>-client-id`). People with only the nonlive
      directory can't read it, so ask Ashok Nannuri or platops.
- [ ] 2. Federation: the same two subjects under **DTS AMp Preview** (and **DTS AMp Demo**). It takes about 5 minutes
      after the merge before Azure accepts the login (`AADSTS700213` until then).
- [ ] 3. Variables `AZURE_CLIENT_ID_PREVIEW`, `AZURE_SUBSCRIPTION_PREVIEW`, `AZURE_SUBSCRIPTION_ID_PREVIEW`
      (and `_DEMO`), copied from courtschedule.
- [ ] 4. `preview.tfvars`: stg tenant, `entra_client_id` = the stg API app, `service_host = "sitamp01-appgw.sit.nl.cjscp"`.
      The plan adds 6 for a new environment, and sbox and demo show no changes.
- [ ] 5. **Releases.** API: GitHub release `vX.Y.Z` → package `X.Y.Z`. Service: depend on `X.Y.Z` (the release gate
      `validateApiSpecVersions` rejects draft versions, ADR 002 in the service repo), merge, then GitHub release
      `vX.Y.Z` → image `X.Y.Z_<time>` from the release run's Wait-ACR-Copy log.
- [ ] 6. `cp-vp-aks-deploy` PR into **`env/sit`**: **all three** of `apps_to_deploy`, the `services_values.yml`
      block (release tag) and `sit.yml` (`AUTH_TENANT_ID` stg, `AUTH_AUDIENCE` = stg API app,
      `AUTH_ROLES: app.read`, `PUBLIC_BASE_URL: https://sps-api-mgmt.preview.api.hmcts.net/amp/cpci/v1`).
- [ ] 7. Pipeline 434 with the SIT values. The cluster is **CL01**, not CL02.
- [ ] 8. CJSCPPUID mapping in `vars/sit.tfvars` (`KV-SIT-CCM-01` / `RG-SIT-KV-CCM-01`) + pipeline 550.
      **Find the SIT user id with the query below. Don't copy dev's.**
- [ ] 9. Subscription key on the preview product. There's no self-service without a portal account, so ask the AMp team.
- [ ] 10. Smoke test against the preview URL with a stg token.

## Pipeline 434 (deploy to AKS)

https://dev.azure.com/hmcts-cpp/cpp-apps/_build?definitionId=434. Set every field. The defaults point at STE,
and the `env/sit` branch's `cpbackendenv` default (`steccm64`) is wrong for SIT.

| Field | Dev | SIT |
| --- | --- | --- |
| Branch | `env/dev` | `env/sit` |
| Environment | `dev` | `sit` |
| CP Backend Target Environment | `steccm64` | `sitccm01` |
| Stack | `devamp01` | `sitamp01` |
| Cluster | `K8-DEV-CS01-CL01` | `K8-SIT-CS01-CL01` |
| `delete_ns` | **unticked** | **unticked** |

The pipeline redeploys every service in `apps_to_deploy`, not just yours. A service missing from that file is
skipped silently, and the run is still green.

Check the pod (on the VPN):
```bash
kubectl --context K8-SIT-CS01-CL01 get pods -n ns-sit-amp-01 | grep caseingestion   # or K8-DEV-CS01-CL01 / ns-dev-amp-01
# no context yet:
az aks get-credentials -g RG-SIT-CS01-CL01 -n K8-SIT-CS01-CL01 --subscription e6b5053b-4c38-4475-a835-a025aeb3d8c7 \
  && kubelogin convert-kubeconfig -l azurecli
```

## CJSCPPUID mapping (cpp-terraform-federation-credentials + pipeline 550)

The service reads each caller's CP user from Key Vault secret `CIVIL-<caller client id>`. If it's missing, the
call fails with `403 CALLER_NOT_ONBOARDED`. The secret comes from `cjscppuid_mappings` in
`vars/<env>.tfvars` (dev: PR #58; SIT: PRs #63 and #64):

```hcl
cjscppuid_key_vault = { name = "KV-SIT-CCM-01", resource_group = "RG-SIT-KV-CCM-01" }
cjscppuid_mappings = {
  "e5b947ce-a761-4373-a437-2e21447d4808" = "463b33a1-1dec-4d1c-ae55-07369f43451a"   # caller client id = CP user id
}
```

**A merge doesn't apply it.** The pipeline has `trigger: none`. Run pipeline 550 by hand:
https://dev.azure.com/hmcts-cpp/cpp-apps/_build?definitionId=550&_a=summary. Never use the defaults: they run
against every environment, including prp, prd and mpd, and apply other teams' drift.

| Field | Value |
| --- | --- |
| Branch | `main` |
| `tfversion` | default (`1.13.3`) |
| `overrideAction` | `apply` |
| `targetResources` | `azurerm_key_vault_secret.cjscppuid_mapping["<caller client id>"]` |
| `planEnvironments` | one line, box cleared first: `[{platform: nonlive, environments: [sit]}]`. Multi-line or leftovers give "Mapping values are not allowed" / "did not find expected ',' or ']'" |

**Before approving:**
1. Stage **Terraform Plan (nonlive)** has only the job **Terraform plan <env>**.
2. The end of its plan log shows only your `cjscppuid_mapping[…]` line, as `will be created` or `will be updated in-place`.
3. The summary is `1 to add, 0 to change, 0 to destroy` (new) or `0 to add, 1 to change, 0 to destroy` (changed).
4. Anything else (for example `azurerm_api_management_api.apis["slc"]` drift) → reject.

The PR's own plan isn't targeted, so it does show that drift. Judge the approval on the run's plan. After the
apply, wait 5 minutes before testing, because the service caches a found mapping for 300 s.

**Finding the CP user.** CP accepts a user whose role has `CIVIL_CASE` / `GrantAccess`. The user is
`civilcase@hmcts.gov`, but its **id differs per environment**. Run this in that environment's usersgroups viewstore:
```sql
select distinct u.id, u.email, r.label
from cpp_permission p
join cpp_role_permission rp on rp.permission_id = p.id
join cpp_role r on r.id = rp.role_id
join cpp_user_role ur on ur.role_id = r.id
join cpp_user u on u.id = ur.user_id
where p.object = 'CIVIL_CASE' and p.action = 'GrantAccess';
```
To read submissions back (GET), the CP user must also pass CP's prosecuting-authority check, added in
CIMD-4110. One of its groups must be Legal Advisers, Court Administrators or Court Associate, or carry the
submission's `prosecuting_authority`. Groups come through roles:
`cpp_user_role` → `cpp_group_role` → `cpp_group`. `cpp_user_group` is now `historical_cpp_user_group`.

## Smoke test (the person's own terminal)

```bash
# SIT. For dev use the sandbox token helper and URL: see Step 8 of the runbook.
export SIT_BASE=https://sps-api-mgmt.preview.api.hmcts.net/amp/cpci/v1      # no trailing slash
RESP=$(curl -s -X POST "https://login.microsoftonline.com/db827888-77df-4707-b3d9-24a3dfe32889/oauth2/v2.0/token" \
  -d grant_type=client_credentials -d client_id="$SIT_CLIENT_ID" -d client_secret="$SIT_CLIENT_SECRET" \
  -d scope="6ce2737c-86bc-4e5c-8399-e3986c598879/.default")
export SIT_TOKEN=$(echo "$RESP" | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')
curl -s -w '\n%{http_code}\n' -H "Authorization: Bearer $SIT_TOKEN" -H "Ocp-Apim-Subscription-Key: $SIT_SUB_KEY" \
  -H "Accept: application/vnd.hmcts.cjs.cpci-submission-details+json" "$SIT_BASE/submissions/00000000-0000-0000-0000-000000000001"
```

| Result | Meaning |
| --- | --- |
| `404 NOT_FOUND` (unknown id) | The whole chain works: token, APIM, pod, Key Vault mapping, CP |
| `POST /cases` → `202` with `statusURL` on the right public URL | Submit works, and `PUBLIC_BASE_URL` is right |
| `401` "JWT token failed CNP validation" / "Missing CNP Authorization header." | Token wrong or missing (APIM) |
| `403 CALLER_NOT_ONBOARDED` | No `CIVIL-<caller>` secret yet (pipeline 550 not applied, or still cached) |
| `403 BACKEND_FORBIDDEN` | CP refused the mapped user: wrong id for this environment, or no `CIVIL_CASE` |
| `400` "The prosecutor information does not match" | CP user isn't in a group for that prosecutor (see above) |
| `404` "No mapping for POST /v1/cases/" (pod log) | Trailing slash in the URL |
| APIM `5xx` | APIM can't reach the backend host. Check the ingress and appgw directly on the VPN |

Read the pod log for a call by its `traceId`:
```bash
kubectl --context K8-SIT-CS01-CL01 logs -n ns-sit-amp-01 deploy/caseingestion-case -c springboot-app --since=15m | grep <traceId>
```

## Pitfalls seen so far

- Dependabot auto-merges even with failing checks, because `main` has no required checks. Check `main` builds before a release.
- The service release workflow uses the organisation secret `HMCTS_CP_ADO_PAT`. It isn't in the repo's secret
  list, but it works. Don't "fix" it to `HMCTS_ADO_PAT`.
- `env/sit`: pipeline 434 with `K8-SIT-CS01-CL02` fails ("No value found at secret/terraform/sit/K8-SIT-CS01-CL02/…").
- APIM demo returns 502 on `demo.api.hmcts.net`. Use the `sps-api-mgmt.<env>.api.hmcts.net` hosts.
