#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT
source1="$workspace/blueprint-1"
source2="$workspace/blueprint-2"
project="$workspace/project"
mkdir -p "$source1/scripts" "$source2/scripts"
cp "$root/scripts/arcturus-update" "$source1/scripts/arcturus-update"
cp "$root/scripts/arcturus-update" "$source2/scripts/arcturus-update"
printf '1.0.0\n' > "$source1/VERSION"
printf '1.1.0\n' > "$source2/VERSION"

cat > "$source1/scripts/arcturus-setup" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == init ]]; shift
project=""; dry=false
while (($#)); do
  case "$1" in
    --project-dir) project="$2"; shift 2 ;;
    --dry-run) dry=true; shift ;;
    *) shift ;;
  esac
done
[[ -n "$project" ]]
$dry && exit 0
mkdir -p "$project/.arcturus"
[[ -f "$project/.arcturus/project.env" ]] || printf 'ARCTURUS_SERVICE=example\n' > "$project/.arcturus/project.env"
printf '1.0.0\n' > "$project/generated-version"
STUB
chmod +x "$source1/scripts/arcturus-setup"

cat > "$source2/scripts/arcturus-setup" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == init ]]; shift
project=""; dry=false
while (($#)); do
  case "$1" in
    --project-dir) project="$2"; shift 2 ;;
    --dry-run) dry=true; shift ;;
    *) shift ;;
  esac
done
[[ -n "$project" ]]
$dry && exit 0
mkdir -p "$project/.arcturus"
[[ -f "$project/.arcturus/project.env" ]] || printf 'ARCTURUS_SERVICE=example\n' > "$project/.arcturus/project.env"
printf '1.1.0\n' > "$project/generated-version"
STUB
chmod +x "$source2/scripts/arcturus-setup"

"$source1/scripts/arcturus-update" bootstrap --project-dir "$project" --service example --non-interactive
[[ -x "$project/scripts/arcturus-update" ]]
grep -q '1.0.0' "$project/.arcturus/bootstrap.json"
[[ "$(wc -l < "$project/.arcturus/bootstrap-history.jsonl")" -eq 1 ]]
grep -q '^.arcturus/blueprint/$' "$project/.gitignore"

"$project/scripts/arcturus-update" apply --project-dir "$project" --from "$source2"
grep -q '1.1.0' "$project/generated-version"
grep -q '1.1.0' "$project/.arcturus/bootstrap.json"
[[ "$(wc -l < "$project/.arcturus/bootstrap-history.jsonl")" -eq 2 ]]
"$project/scripts/arcturus-update" show --project-dir "$project" | grep -q './scripts/arcturus-update apply'

before="$(sha256sum "$project/.arcturus/bootstrap.json")"
"$project/scripts/arcturus-update" apply --project-dir "$project" --from "$source2" --dry-run
[[ "$before" == "$(sha256sum "$project/.arcturus/bootstrap.json")" ]]

git -C "$project" init -q
mkdir -p "$project/.arcturus/blueprint"
cp -a "$source2/." "$project/.arcturus/blueprint/"
(
  cd "$project"
  ./scripts/arcturus-update apply
)
python3 - "$project/.arcturus/bootstrap.json" <<'PY'
import json, sys
state = json.load(open(sys.argv[1], encoding='utf-8'))
assert state['blueprintCommit'] == 'unknown'
assert len(state['blueprintFingerprintSha256']) == 64
PY
[[ "$(wc -l < "$project/.arcturus/bootstrap-history.jsonl")" -eq 3 ]]

echo 'Updater tests passed.'
