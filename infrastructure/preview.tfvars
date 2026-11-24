api_mgmt_rg   = "rg-sps-platform-preview"
api_mgmt_name = "sps-api-mgmt-preview"

apim_product = {
  name                  = "cp-civil-caseingestion"
  subscription_required = true
  subscriptions_limit   = 20
  approval_required     = false
  published             = true
  # APIM attaches the administrators group to every new product itself (see sbox.tfvars).
  product_access_control_groups = ["developers", "guests"]
}

# Preview uses external-entra-id's stg tenant and its own amp-api-caseingestion app there
# (external-entra-id #66), not the sbox one.
entra_tenant_id = "db827888-77df-4707-b3d9-24a3dfe32889"
entra_client_id = "a246e00b-875f-4782-ad03-d92c355ff33a"

# Preview fronts SIT (demo does not connect to CP): public URL https://sps-api-mgmt.preview.api.hmcts.net/amp/cpci/v1/...,
# backend sitamp01, the SIT ingress of the service (ns-sit-amp-01).
apis = {
  v1 = {
    openapi_spec_path   = "../src/main/resources/openapi/v1/openapi.yml"
    name                = "api-common-platform-case-interface-v1"
    display_name        = "Civil Case Ingestion Case API (cpci) v1"
    path                = "amp/cpci/v1"
    service_host        = "sitamp01-appgw.sit.nl.cjscp"
    service_path        = "/cpci/v1"
    revision            = "1"
    required_roles      = ["app.read"]
    try_it_auth_headers = true
  }
}

# No entra_token_helper: the token helper is sandbox only.
