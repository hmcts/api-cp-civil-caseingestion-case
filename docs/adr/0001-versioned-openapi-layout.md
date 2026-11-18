# ADR 0001: One folder, Java package and APIM API per major API version

- Status: Accepted
- Date: 2026-11-18
- Ticket: CIMD-4175

## Context

The API had one spec at `src/main/resources/openapi/openapi.yml` and unversioned URLs
(`amp/cpci/cases`). The tech lead asked for:

1. versioned URLs: `amp/cpci/v1/cases`, `amp/cpci/v1/submissions/{id}`
2. a versioned API
3. a spec layout of `openapi/v1/paths`, `openapi/v2/paths`, ...

The repo was created from `api-hmcts-crime-template`, which has a single unversioned spec. Constraints found:

- The shared APIM module `cnp-module-api-mgmt-api` has no API version-set support.
- `hmcts/update-openapi-version` stamps only the first `*openapi*.yml` it finds and uploads it under a
  fixed artifact name, so it cannot run once per version in one workflow.
- CI overwrites `servers[0].url` (`https://<repo>.net/{version}`), so `servers` cannot carry the version.

## Decision

- Each major version lives in `src/main/resources/openapi/v<N>/` (`openapi.yml`, `paths/`, `schemas/`).
  Paths inside it are version-free (`/cases`).
- `build.gradle` registers one generate task per version folder, into `uk.gov.hmcts.cp.openapi.v<N>.api` and
  `.v<N>.model`. One published package contains every version.
- `.github/scripts/bundle-openapi-versions.sh` bundles each version folder and stamps `info.version` and
  `servers` as `hmcts/update-openapi-version` did. `ci-draft.yml` and `ci-released.yml` use it in place of
  that action and upload the whole versioned folder as one attested artifact. `terraform-infra.yaml` uses
  it to bundle before Terraform, `lint-openapi.yml` lints each version, and `publish-api-docs.yml`
  publishes each version with a version picker.
- APIM: one API per major version, all in the existing product `cp-civil-caseingestion`, at
  `amp/cpci/v<N>`, forwarding to the service at `/cpci/v<N>`. The service maps each generated
  package's controllers under `/v<N>`.

## Consequences

- Public and service URLs carry the major version; v1 and v2 can run side by side in one service.
- Callers keep their subscription key across versions (it belongs to the product), and their Entra
  credentials.
- This repo departs from `api-hmcts-crime-template` in its layout and in not using
  `hmcts/update-openapi-version`. If the template team adopts versioning, this repo should move back to
  the shared mechanism.
- Breaking change for existing callers of the unversioned URLs (only internal testing at the time).

## Alternatives considered

- `/v1` written into every path in a single spec: same URLs, but a later v2 would need a second APIM API
  with an overlapping path, or a merged spec.
- APIM version sets: not supported by the shared module; would need hand-written `azurerm` resources.
- One published package per version: more dependencies and no single service build for several versions.
