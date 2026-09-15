#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
dockerfile="${script_dir}/Dockerfile"
entrypoint="${script_dir}/entrypoint.sh"

image_ref="${1:-}"

echo "Checking dev-paseo entrypoint syntax..."
bash -n "${entrypoint}"

echo "Checking the image default shell..."
if ! grep -Eq '^[[:space:]]+SHELL=/bin/zsh[[:space:]]+\\$' "${dockerfile}"; then
  echo "Expected dev-paseo Dockerfile to set SHELL=/bin/zsh" >&2
  exit 1
fi

if [ -n "${image_ref}" ]; then
  echo "Checking SHELL in the final image environment..."
  docker run --rm --entrypoint /bin/sh "${image_ref}" -eu -c '[ "${SHELL:-}" = /bin/zsh ]'
fi

echo "dev-paseo shell smoke test passed."
