api_mgmt_rg   = "rg-sps-platform-preview"
api_mgmt_name = "sps-api-mgmt-preview"

# Consumer subscriptions (subscriptions.tf, as in courtschedule): each consumer gets its own
# API-scoped APIM subscription, owned by the shared 'amp-subscriptions' user, and its key is
# stored in this Key Vault as amp-apim-sub-preview-<consumer>-<api>-primary-key.
subscription_key_vault_name = "kvspsplatformpreview"
create_subscription_user    = true

apim_product = {
  name                  = "cp-civil-caseingestion"
  subscription_required = true
  subscriptions_limit   = 20
  approval_required     = false
  published             = true
  # APIM attaches the administrators group to every new product itself (see sbox.tfvars).
  product_access_control_groups = ["developers", "guests"]
}

# Preview uses external-entra-id's stg tenant and its amp-api-cpci app there
# (external-entra-id #66, renamed from amp-api-caseingestion in #70), not the sbox one.
entra_tenant_id = "db827888-77df-4707-b3d9-24a3dfe32889"
entra_client_id = "6ce2737c-86bc-4e5c-8399-e3986c598879"

# Preview fronts SIT (demo does not connect to CP): public URL https://sps-api-mgmt.preview.api.hmcts.net/amp/cpci/v1/...,
# backend sitamp01, the SIT ingress of the service (ns-sit-amp-01).
apis = {
  v1 = {
    openapi_spec_path   = "../src/main/resources/openapi/v1/openapi.yml"
    name                = "api-common-platform-cpci-interface-v1"
    display_name        = "Civil Case Ingestion Case API (cpci) v1"
    path                = "amp/cpci/v1"
    service_host        = "sitamp01-appgw.sit.nl.cjscp"
    service_path        = "/cpci/v1"
    revision            = "1"
    required_roles      = ["app.read"]
    try_it_auth_headers = true
    consumers           = ["amp-enforcement-external-client"]
  }
}

# No entra_token_helper: the token helper is sandbox only.
