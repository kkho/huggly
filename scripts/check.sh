#!/usr/bin/env bash
# Builds Huggly, compiles a sample system for every environment and validates the Terraform.
# Usage (from anywhere in the repo): scripts/check.sh [system] default system: Conferenti
set -uo pipefail

SYSTEM="${1:-Conferenti}"
ENVIRONMENTS=(dev test prod)

cd "$(dirname "$0")/.."

fail() {
  echo
  echo "CHECK FAILED - $1"
  exit 1
}

# Runs a command quietly; prints its output only when it fails
quiet() {
  local output
  if ! output=$("$@" 2>&1); then
    echo "$output"
    return 1
  fi
}

dotnet build Huggly.CLI.slnx -nologo -v q || fail "build"

for env in "${ENVIRONMENTS[@]}"; do
  echo
  echo "=== $env ==="

  dotnet run --no-build --project src/Huggly.CLI -- compile \
    --definitions "src/huggly-templates/Systems/$SYSTEM" \
    --environment "$env" \
    --output huggly-outputs || fail "compile ($env)"

  pushd "huggly-outputs/$env/$SYSTEM" > /dev/null
  terraform init -backend=false -input=false || fail "terraform init ($env)"
  terraform validate -no-color || fail "terraform validate ($env)"
  popd > /dev/null
done

echo
echo "All environments compile and validate."