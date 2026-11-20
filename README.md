# API CP Case Ingestion Case

This API provides case submission information used by the Common Platform Case Interface (CPCI).

It defines the inbound case-creation surface (`POST /cases` for other and summons case types) and the
submission status polling endpoint (`GET /submissions/{submissionId}`).

## Versions

Each major API version has its own folder and its own URL prefix:

| Version | Spec | Public URL (sandbox APIM) | Generated Java packages |
|---|---|---|---|
| v1 | `src/main/resources/openapi/v1/openapi.yml` (+ `paths/`, `schemas/`) | `https://sandbox.api.hmcts.net/amp/cpci/v1/...` | `uk.gov.hmcts.cp.openapi.v1.api`, `uk.gov.hmcts.cp.openapi.v1.model` |

A v2 ran beside v1 on dev as a trial (added 2026-11-19, removed 2026-11-20). Only v1 is live.

Paths inside a version folder are written without the version (`/cases`); the folder, the APIM path and the
service's `/v1` prefix carry it. To start a v2, copy `openapi/v1` to `openapi/v2`, make the breaking change
there, give its request media types the new version (`...cpci-other-cases.v2+json`), and add a `v2` entry to
`apis` in `infrastructure/sbox.tfvars`. The build generates every version
folder it finds, and CI bundles, versions and publishes them together in one package. See
[ADR 0001](docs/adr/0001-versioned-openapi-layout.md).

## Documentation

The published OpenAPI documentation is available at
[hmcts.github.io/api-cp-civil-caseingestion-case](https://hmcts.github.io/api-cp-civil-caseingestion-case/).

Further documentation see the [API Template repository readme](https://github.com/hmcts/api-cp-template?tab=readme-ov-file#api-cp-template-repository).

## License

This project is licensed under the [MIT License](LICENSE).
