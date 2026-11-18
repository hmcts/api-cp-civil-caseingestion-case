api_mgmt_rg   = "rg-sps-platform-sbox"
api_mgmt_name = "sps-api-mgmt-sbox"

apim_product = {
  name                  = "cp-civil-caseingestion"
  subscription_required = true
  subscriptions_limit   = 20
  approval_required     = false
  published             = true
  # APIM attaches the administrators group to every new product itself, so it is not listed here.
  # Listing it makes the first apply fail ("already exists") and needs an import on every rebuild.
  product_access_control_groups = ["developers", "guests"]
}

entra_tenant_id = "d44f885c-4fac-47bf-afde-d7d861ec4d7b"
entra_client_id = "6474e0e1-d2b3-4383-a7d0-5253c8dc9ff4"

# One APIM API per major API version (openapi/v1, later openapi/v2), all in the same product, so
# callers keep one subscription key across versions. Public URL: amp/cpci/v1/...; the service
# serves the same version under /v1 behind the /cpci route.
apis = {
  v1 = {
    # The source spec is modular ($ref to paths/ and schemas/). Terraform reads it with file(),
    # so terraform-infra.yaml bundles each version folder in place before Terraform runs.
    openapi_spec_path = "../src/main/resources/openapi/v1/openapi.yml"
    # Explicit, because every version shares the spec's info.title.
    name           = "api-common-platform-case-interface-v1"
    display_name   = "Civil Case Ingestion Case API (cpci) v1"
    path           = "amp/cpci/v1"
    service_host   = "devamp01-appgw.dev.nl.cjscp"
    service_path   = "/cpci/v1"
    revision       = "1"
    required_roles = ["app.read"]
    # Pre-filled Authorization and Accept boxes in the portal's Try it (see apis.tf).
    try_it_auth_headers = true
  }
}

# Lets clients get a token with their own credentials in the sandbox portal (see entra-token.tf).
entra_token_helper = {
  app_insights_logger_name = "sps-api-mgmt-sbox-logger"
}
