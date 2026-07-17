#!/usr/bin/env bash
set -euo pipefail
: "${CI_COMMIT_SHA:?set the full 40-character commit SHA}"
: "${ARCTURUS_DEPLOY_TOKEN:?set ARCTURUS_DEPLOY_TOKEN from protected CI secrets}"
# External registry projects also provide REGISTRY_TOKEN and optionally
# REGISTRY_USER. Owned-registry projects instead join the tailnet before this
# entrypoint; scripts/arcturus-ci requests short-lived upload credentials.
exec ./scripts/arcturus-ci "$CI_COMMIT_SHA"
