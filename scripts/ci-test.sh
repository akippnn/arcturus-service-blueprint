#!/usr/bin/env bash
set -euo pipefail

if [[ -f package-lock.json ]]; then
  npm ci
  npm test --if-present
  npm run build --if-present
  exit 0
fi

echo "No test adapter is configured. Replace scripts/ci-test.sh for this service." >&2
exit 1
