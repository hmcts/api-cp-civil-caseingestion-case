---
name: add-api-version
description: Add (or retire) a major version of this API (v2, v3, ...) beside the existing ones — new openapi/vN folder, versioned media types, APIM entries in every tfvars, version-specific controllers and mappers in service-cp-civil-caseingestion-case, tests and deployment. Use whenever someone asks to add a new API version, make a breaking change, run v1 and v2 side by side, or remove an old version, even if they don't say "skill".
---

# Add a new API version (vN)

A breaking change becomes a new major version **beside** the old ones. Existing callers keep working and keep
their token, client id and subscription key. Only their URL changes to `/vN/`. The layout is recorded in
[ADR 0001](../../../docs/adr/0001-versioned-openapi-layout.md).

We did this for real on 19 Nov 2026: v2 of both endpoints beside v1 (API #12, service #5, cp-vp-aks-deploy #166),
removed again on 20 Nov (API #13, service #6, cp-vp-aks-deploy #167). It took one working day, and nobody outside
the team was needed: no Entra, federation, product, key or route change.

Full story: https://hmcts.atlassian.net/wiki/spaces/DATAIN/pages/391775615/CPCI-new-API-runbook
("Adding a new API version").

## Checklist

API repo (`api-cp-civil-caseingestion-case`), one PR:
- [ ] Copy `src/main/resources/openapi/v1` → `openapi/vN`; set `info.version` (e.g. `"N.0"`); make the breaking change in `vN` only.
- [ ] If the request body changes, version its media types: `application/vnd.hmcts.cjs.cpci-other-cases.vN+json`
      (and `cpci-summons.vN+json`). A body for one version sent to another then gets 415.
- [ ] Keep `configPackage: "org.openapitools.configuration.${v}"` in `build.gradle`'s per-version `configOptions`.
      Without it two versions generate the same `EnumConverterConfiguration` class and don't compile.
- [ ] Add a `vN` entry under `apis` in **every** tfvars: `sbox.tfvars` (dev), `preview.tfvars` (SIT), `demo.tfvars`.
- [ ] README "Versions" table; a consequence in ADR 0001 if anything new was learned.
- [ ] Build locally (there's no wrapper in this repo): `~/repo/service-cp-civil-caseingestion-case/gradlew -p . build -DAPI_SPEC_VERSION=1.6`.
      It must generate `build/generated/v1` … `vN`.
- [ ] PR plans: each environment shows **3 to add** (API, policy, product link), 0 to change, 0 to destroy.
- [ ] Merge → package `0.0.0-<commit>` with all versions, and `amp/cpci/vN` exists in APIM. It returns 404 from the
      service until the next part is deployed. That's expected.

Service repo (`service-cp-civil-caseingestion-case`), one PR:
- [ ] Depend on the new API package.
- [ ] Copy `controllers/v1` → `controllers/vN` and `mappers/v1` → `mappers/vN`. Switch imports to `uk.gov.hmcts.cp.openapi.vN.*`
      and set the vN media type in `vN/OtherCasesBodyAdvice` (`super(OTHER_CASES, OtherCases.class)`).
- [ ] `ApiVersionConfig`: a `VN = "vN"` constant and one line,
      `configurer.addPathPrefix("/" + VN, HandlerTypePredicate.forBasePackage(CONTROLLERS + VN));`
- [ ] Each version's `CasesController` builds its `statusURL` with `publicApi.statusUrl(ApiVersionConfig.VN, id)`.
- [ ] Don't touch the version-neutral core (`CaseIngestionClient`, `CaseIngestionService` and the domain records
      `CivilSubmissionAccepted` and `CivilSubmissionDetails`) or `OtherCasesBodyAdviceSupport`. Generated `openapi.vN` classes
      only appear in `controllers.vN` and `mappers.vN`.
- [ ] Tests: `CasesVNIntegrationTest` and `SubmissionsVNIntegrationTest` (at least one per endpoint, plus the
      cross-version 415), mapper and controller unit tests. **Leave the v1 tests unchanged**; they prove v1 still behaves.
- [ ] `JAVA_HOME=<JDK 25> ./gradlew build` green.

Deploy:
- [ ] Dev: tag-only PR in `cp-vp-aks-deploy` `env/dev` (`vp-config/services_values.yml`), then pipeline 434 (see the
      `deploy-api` skill). No route or setting change: `/cpci/vN/...` sits under the existing `/cpci` route, and
      `PUBLIC_BASE_URL` with a trailing `/v1` still works because the service strips it.
- [ ] SIT: release the API and the service (fixed versions), then a tag-only PR in `env/sit` and pipeline 434 with the SIT values.
- [ ] Smoke test `…/amp/cpci/v1/…` and `…/amp/cpci/vN/…` with the same token and subscription key. A vN POST returns a
      `statusURL` ending `/amp/cpci/vN/submissions/<id>`.

## Building the service before the API is published

The service can't use an unbundled local spec: it generates broken models (for example "Cannot construct instance of
OtherCases"). To build against an unpublished API branch:
1. Copy the API repo into a folder named **exactly** `api-cp-civil-caseingestion-case` (the artifact name comes from the folder).
2. In the copy, run `.github/scripts/bundle-openapi-versions.sh` (needs `npx @redocly/cli`).
3. Run `gradle build -x test publishToMavenLocal -DAPI_SPEC_VERSION=0.0.999` there, and point the service's `build.gradle` at `0.0.999`.
4. Switch back to the published version before merging.

## Retiring a version

Order: API first, then service, then deploy. That's 3 PRs; doing the service first would take 4.
1. API repo: delete `openapi/vN` and the `vN` entry in every tfvars. Each environment's plan **only destroys** the 3 vN
   resources, and APIM then answers 404 for `amp/cpci/vN`. Keep `configPackage` and the per-version build support.
2. Service: move to the new package; delete `controllers/vN`, `mappers/vN`, the vN tests, the `VN` constant and its
   prefix line. Add integration tests that `/vN/cases` and `/vN/submissions/{id}` return 404 and are never forwarded.
3. Tag-only deploy PR and pipeline 434 per environment, then smoke test: vN gives 404 from APIM, and the other versions are unchanged.
