#!/usr/bin/env bash
set -euo pipefail
: "${CI_COMMIT_SHA:?set the full commit SHA}"
: "${REGISTRY_USER:?set REGISTRY_USER from protected CI secrets}"
: "${REGISTRY_TOKEN:?set REGISTRY_TOKEN from protected CI secrets}"
: "${ARCTURUS_DEPLOY_TOKEN:?set ARCTURUS_DEPLOY_TOKEN from protected CI secrets}"
: "${ARCTURUS_REGISTRY_HOST:?set the registry hostname}"
exec ./scripts/arcturus-ci "$CI_COMMIT_SHA"
