# Updating an Arcturus-enabled project

The blueprint updater turns the project's tracked `.arcturus/project.env` into a replayable migration contract. The setup tool still owns generation and preserves modified generated files; the updater adds provenance, history, and a one-command path for later blueprint releases.

## Bootstrap a new project

Run the updater from a blueprint checkout instead of invoking `arcturus-setup` directly:

```bash
/path/to/arcturus-service-blueprint/scripts/arcturus-update bootstrap \
  --project-dir /path/to/my-api \
  --service my-api \
  --type web \
  --image-repository registry.example.org/team/my-api \
  --domain api.example.org \
  --deploy-url 'http://192.0.2.10:9090' \
  --bundle 'registry.example.org/platform/arcturus@sha256:<64-hex-digest>' \
  --non-interactive
```

This runs the normal idempotent setup, installs `scripts/arcturus-update` into the application repository, and writes:

| File | Purpose |
| --- | --- |
| `.arcturus/project.env` | Canonical non-secret setup intent used for replay |
| `.arcturus/bootstrap.json` | Current blueprint version, commit, tree fingerprint, normalized setup command, and updater checksum |
| `.arcturus/bootstrap-history.jsonl` | Append-only record of successful bootstrap and update operations |
| `scripts/arcturus-update` | Project-local update entrypoint |

The normalized command deliberately uses `.` and `${ARCTURUS_BLUEPRINT_DIR}` instead of recording workstation-specific absolute paths. No CI token, registry token, or application secret is written.

## Drag-and-drop update

1. Download or clone the newer blueprint release.
2. Replace the project's ignored `.arcturus/blueprint/` directory with the extracted blueprint folder. The folder must contain `VERSION` and `scripts/arcturus-setup`.
3. From the application repository, inspect the planned migration:

```bash
./scripts/arcturus-update apply --dry-run
```

4. Apply it:

```bash
./scripts/arcturus-update apply
```

The updater invokes the new blueprint's setup command with the existing `.arcturus/project.env`. Generator-owned files update automatically when they are unchanged. Locally modified generated files remain in place and proposed replacements are written under `.arcturus/updates/`.

The dropped `.arcturus/blueprint/` directory is ignored by Git and may be deleted after a successful update.

## Update from another directory

A copied folder is optional. Point directly to a checkout or extracted release:

```bash
./scripts/arcturus-update apply --from /path/to/arcturus-service-blueprint
```

Use `--force` only after reviewing the generated proposals. It forwards the existing setup tool's backup-and-replace behavior and also permits replacement of a locally modified updater after making a timestamped backup.

## Inspect provenance

```bash
./scripts/arcturus-update show
```

This prints the blueprint version and commit, the normalized setup command that produced the current state, and the canonical next-update command. Commit `.arcturus/bootstrap.json`, `.arcturus/bootstrap-history.jsonl`, `.arcturus/project.env`, and the generated changes with the application repository so another operator or automation agent can reproduce the same bootstrap intent.

## Migrating an existing project

For a project already created with `arcturus-setup`, run the newer updater in bootstrap mode using the current project settings. When `.arcturus/project.env` already exists, it remains the source of truth:

```bash
/path/to/new-blueprint/scripts/arcturus-update bootstrap \
  --project-dir /path/to/existing-project \
  --config /path/to/existing-project/.arcturus/project.env \
  --non-interactive
```

Review `.arcturus/updates/` before committing. The project-owned `.arcturus/project.json` is not overwritten automatically.
