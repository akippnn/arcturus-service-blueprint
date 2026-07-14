#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
bundle='registry.example.org/platform/arcturus@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

web="$workspace/web"
"$root/scripts/arcturus-setup" init \
  --project-dir "$web" --service example-web --type web \
  --image-repository registry.example.org/team/example-web \
  --domain web.example.org --deploy-url http://192.0.2.10:9090 \
  --bundle "$bundle" --test-command true --systemd-health --non-interactive
python3 -m json.tool "$web/arcturus.release.json" >/dev/null
python3 -m json.tool "$web/.arcturus/project.json" >/dev/null
test -f "$web/AGENTS.md"
(cd "$web" && ./scripts/arcturus-guard)
grep -q 'arcturus-ci' "$web/.gitea/workflows/deploy.yaml"
grep -q '^name: Deploy example-web$' "$web/.gitea/workflows/deploy.yaml"
grep -q '^name: Manage example-web$' "$web/.gitea/workflows/lifecycle.yaml"
grep -q '^name: Test example-web rollback$' "$web/.gitea/workflows/acceptance.yaml"
grep -q 'project preflight' "$web/scripts/arcturus-ci"
! grep -R -E 'DEPLOY_WEBHOOK_SECRET|REGISTRY_PASSWORD|/deploy(["[:space:]]|$)' "$web/.gitea/workflows"

cp "$web/arcturus.release.json" "$web/arcturus.release.json.valid"
python3 - "$web/arcturus.release.json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as stream:
    manifest = json.load(stream)
component = next(iter(manifest["spec"]["routing"].values()))["component"]
manifest["spec"]["components"][component]["networks"] = ["app"]
with open(path, "w", encoding="utf-8") as stream:
    json.dump(manifest, stream, indent=2)
    stream.write("\n")
PY
if (cd "$web" && ./scripts/arcturus-guard >/dev/null 2>&1); then
  echo "guard accepted a routed component without internal_routing" >&2
  exit 1
fi
mv "$web/arcturus.release.json.valid" "$web/arcturus.release.json"
grep -q '"domains": \[' "$web/arcturus.release.json"
first="$(sha256sum "$web/arcturus.release.json")"
"$root/scripts/arcturus-setup" init --project-dir "$web" \
  --config "$web/.arcturus/project.env" --bundle "$bundle" --non-interactive
[[ "$first" == "$(sha256sum "$web/arcturus.release.json")" ]]

python3 - "$web/.arcturus/project.json" <<'PY'
import json, sys
path = sys.argv[1]
project = json.load(open(path))
project["builds"]["app"]["components"] = ["app"]
project["verification"]["publicMode"] = "skip"
project["ci"]["testIntent"] = {"mode": "command"}
json.dump(project, open(path, "w"), indent=2)
PY
"$root/scripts/arcturus-setup" init --project-dir "$web" \
  --config "$web/.arcturus/project.env" --bundle "$bundle" --non-interactive
grep -q '"publicMode": "skip"' "$web/.arcturus/project.json"

printf '\n' >>"$web/arcturus.release.json"
"$root/scripts/arcturus-setup" init --project-dir "$web" \
  --config "$web/.arcturus/project.env" --bundle "$bundle" --non-interactive
test -f "$web/.arcturus/updates/arcturus.release.json.new"

scheduled="$workspace/scheduled"
"$root/scripts/arcturus-setup" init \
  --project-dir "$scheduled" --service example-job --type scheduled \
  --image-repository registry.example.org/team/example-job \
  --exposure internal --schedule '*-*-* 02:00:00' --systemd-health \
  --bundle "$bundle" --test-command true --ci generic --non-interactive
python3 - "$scheduled/arcturus.release.json" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
component = manifest["spec"]["components"]["app"]
assert component["mode"] == "scheduled"
assert component["schedule"]["onCalendar"] == "*-*-* 02:00:00"
assert manifest["spec"]["routing"] == {}
PY

worker="$workspace/worker"
"$root/scripts/arcturus-setup" init \
  --project-dir "$worker" --service example-worker --type worker \
  --image-repository registry.example.org/team/example-worker \
  --bundle "$bundle" --test-command true --ci none --non-interactive
python3 - "$worker/arcturus.release.json" <<'PY'
import json, sys
manifest = json.load(open(sys.argv[1]))
component = manifest["spec"]["components"]["app"]
assert component["mode"] == "service"
assert component["restart"] == "on-failure"
assert "healthCheck" not in component
assert manifest["spec"]["routing"] == {}
PY

node_web="$workspace/node-web"
mkdir -p "$node_web"
printf '{"scripts":{"test":"true"}}\n' >"$node_web/package.json"
"$root/scripts/arcturus-setup" init \
  --project-dir "$node_web" --service node-web --type web \
  --image-repository registry.example.org/team/node-web --domain node.example.org \
  --deploy-url http://192.0.2.10:9090 --bundle "$bundle" --test-command true --non-interactive
python3 - "$node_web/arcturus.release.json" <<'PY'
import json, sys
component = json.load(open(sys.argv[1]))["spec"]["components"]["app"]
assert component["healthCheck"]["command"].startswith("node -e")
assert "wget" not in component["healthCheck"]["command"]
PY

if "$root/scripts/arcturus-setup" init --project-dir "$workspace/invalid" \
  --service invalid --type scheduled --image-repository registry.example.org/team/invalid \
  --exposure internal --bundle "$bundle" --test-command true --non-interactive 2>"$workspace/error"; then
  echo "scheduled setup unexpectedly accepted a missing schedule" >&2
  exit 1
fi
grep -q 'scheduled services require --schedule' "$workspace/error"

legacy="$workspace/legacy"
mkdir -p "$legacy/.arcturus"
cp "$web/.arcturus/project.env" "$legacy/.arcturus/project.env"
"$root/scripts/arcturus-setup" init --project-dir "$legacy" \
  --config "$legacy/.arcturus/project.env" --bundle "$bundle" --non-interactive
test -f "$legacy/.arcturus/project.json"

python3 - "$root/examples/projects/stellar-like/.arcturus/project.json" "$root/examples/projects/stellar-like/arcturus.release.json" <<'PY'
import json, sys
project, manifest = map(lambda path: json.load(open(path)), sys.argv[1:])
assert project["builds"]["web"]["components"] == ["web", "db-init"]
assert set(project["fixedComponents"]) == {"postgres", "redis"}
assert manifest["spec"]["components"]["web"]["image"] == manifest["spec"]["components"]["db-init"]["image"]
assert manifest["spec"]["components"]["postgres"]["volumes"][0]["source"] == "legacy_project_postgres"
assert manifest["spec"]["migration"]["legacyCompose"][0]["project"] == "legacy-project"
PY

stellar="$workspace/stellar-like"
"$root/scripts/arcturus-setup" init \
  --project-dir "$stellar" --service stellar-like --type web \
  --image-repository registry.example.org/example/stellar-like-web \
  --domain stellar-like.example.org --deploy-url http://192.0.2.10:9090 \
  --project-spec "$root/examples/projects/stellar-like/arcturus.project-spec.json" \
  --bundle "$bundle" --test-command true --systemd-health --non-interactive
(cd "$stellar" && ./scripts/arcturus-guard)
python3 - "$stellar/.arcturus/project.json" "$stellar/arcturus.release.json" <<'PY'
import json, sys
project, manifest = map(lambda path: json.load(open(path)), sys.argv[1:])
assert set(manifest["spec"]["components"]) == {"postgres", "redis", "api", "db-init", "web"}
assert project["builds"]["web"]["components"] == ["web", "db-init"]
assert manifest["spec"]["components"]["web"]["dependsOn"] == ["api", "db-init"]
assert manifest["spec"]["routing"]["web"]["component"] == "web"
assert manifest["spec"]["migration"]["legacyCompose"][0]["cleanup"] == "retain"
PY
grep -q 'ARCTURUS_BUILDAH_ROOT' "$root/scripts/arcturus-ci"
! grep -qE 'buildah (rmi|prune)|podman (image|system) prune' "$root/scripts/arcturus-ci"
grep -q 'GITHUB_ACTOR' "$root/scripts/arcturus-ci"
buildah_line="$(grep -n 'command -v buildah' "$root/scripts/arcturus-tool" | head -1 | cut -d: -f1)"
podman_line="$(grep -n 'command -v podman' "$root/scripts/arcturus-tool" | head -1 | cut -d: -f1)"
[[ "$buildah_line" -lt "$podman_line" ]]
grep -q -- '--authfile "$REGISTRY_AUTH_FILE"' "$root/scripts/arcturus-tool"
grep -q 'Buildah is required to pull the pinned Arcturus bundle' "$root/scripts/arcturus-lifecycle"

if [[ "${ARCTURUS_TEST_HOST_INSTALLER:-false}" == true ]]; then
  [[ -f "$root/../arcturus/deploy/install-host.sh" ]] || {
    echo "ARCTURUS_TEST_HOST_INSTALLER=true requires a sibling arcturus checkout" >&2
    exit 2
  }
  "$root/../arcturus/deploy/install-host.sh" --source-dir "$root/../arcturus/deploy" \
    --host-home "$workspace/host-home" --base-domain example.org --dry-run >/dev/null
fi

grep -q '^ARCTURUS_MIN_VERSION=0.99.0-rc.2$' "$web/.arcturus/lock.env"
grep -q '^ARCTURUS_REQUIRED_FEATURES=authenticated-preflight,legacy-compose-handoff$' "$web/.arcturus/lock.env"
grep -q 'REGISTRY_USER:.*secrets.REGISTRY_USER' "$web/.gitea/workflows/deploy.yaml"

echo "Blueprint setup tests passed."
