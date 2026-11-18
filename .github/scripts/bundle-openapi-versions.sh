#!/usr/bin/env bash
# Bundles every API version's modular spec (src/main/resources/openapi/v<N>/openapi.yml plus its
# paths/ and schemas/) into a single self-contained openapi.yml in the same folder.
#
# With a version argument it also stamps each spec the way hmcts/update-openapi-version does:
# info.version and servers[0] (url https://<api name>.net/{version}). That action handles only one
# spec file per workflow, so this script replaces it for the per-version layout.
#
# Usage: bundle-openapi-versions.sh [<artefact version> <api name>]
# Needs @redocly/cli (redocly) on the PATH, and mikefarah yq when stamping.
set -euo pipefail

OPENAPI_DIR="${FILE_PATH_OPENAPI:-src/main/resources/openapi}"
VERSION="${1:-}"
API_NAME="${2:-}"

shopt -s nullglob
dirs=("${OPENAPI_DIR}"/v*/)
if [ ${#dirs[@]} -eq 0 ]; then
  echo "No version folders (v1, v2, ...) found under ${OPENAPI_DIR}" >&2
  exit 1
fi

for dir in "${dirs[@]}"; do
  dir="${dir%/}"
  spec="${dir}/openapi.yml"
  echo "Bundling ${spec}"
  # redocly picks the output format from the extension, so the temporary file must end in .yml
  redocly bundle "${spec}" -o "${dir}/openapi.bundled.yml"
  rm -rf "${dir}/paths" "${dir}/schemas"
  mv "${dir}/openapi.bundled.yml" "${spec}"

  if [ -n "${VERSION}" ]; then
    echo "Stamping ${spec} with version ${VERSION}"
    V="${VERSION}" N="${API_NAME}" yq -i '
      .info.version = strenv(V) |
      .servers[0].url = "https://" + strenv(N) + ".net/{version}" |
      .servers[0].variables.version.default = strenv(V) |
      .servers[0].variables.version.description = "API version; matches the spec info.version"
    ' "${spec}"
  fi
done
