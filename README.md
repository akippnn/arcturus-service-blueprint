# Arcturus Service Blueprint

A public project template and bootstrap tool for deploying applications through the Arcturus manifest-driven, digest-pinned Quadlet control plane.

> **Status:** aligned with Arcturus `v0.99.0-rc.1` and manifest API `arcturus.u128.org/v2`.

The blueprint adds a project-owned build graph, release template, CI adapters, lifecycle commands, acceptance probes, and agent guidance. It does not add a second deployment engine: production ownership remains with Arcturus, rootless Podman, and user systemd.

## Ownership boundaries

| Owner | Responsibility |
| --- | --- |
| Application repository | Source, tests, Containerfiles, project build graph, release template, and non-secret runtime configuration |
| CI | Validate, build, push, resolve digests, render a concrete release, deploy, and verify |
| Arcturus deployer | Authentication, schema validation, locks, image verification, staging, readiness, state, and rollback |
| Quadlet/systemd | Containers, networks, volumes, timers, ordering, restart policy, boot startup, and journald |
| Registry/router | Consume the active release and publish ingress configuration and receipts |
| Terraform | Optional long-lived host/network/bootstrap infrastructure only |
| Compose | Optional local development only |

Production releases never run Terraform, reset a host Git checkout, deploy `latest`, depend on Watchtower, or let Compose and Quadlet own the same container.

## Bootstrap a project

From a blueprint checkout:

```bash
./scripts/arcturus-setup init \
  --project-dir /path/to/my-api \
  --service my-api \
  --type web \
  --image-repository registry.example.org/team/my-api \
  --domain api.example.org \
  --deploy-url 'http://<private-host-address>:9090' \
  --bundle 'registry.example.org/platform/arcturus@sha256:<64-hex-digest>' \
  --non-interactive
```

Omit values and `--non-interactive` for guided setup:

```bash
./scripts/arcturus-setup init --project-dir /path/to/project
```

Run `./scripts/arcturus-setup init --help` for the complete project options. `host` and `all` modes can also validate or invoke the Arcturus host installer.

## Generated contract

The generator creates or updates:

| File | Purpose |
| --- | --- |
| `arcturus.release.json` | Sole production release manifest template |
| `.arcturus/project.json` | Project-owned build, component mapping, CI, registry, and verification graph |
| `.arcturus/project.env` | Non-secret convenience settings |
| `.arcturus/lock.env` | Digest-pinned Arcturus tool bundle and schema lock |
| `scripts/arcturus-*` | Guard, CI, deploy, verify, lifecycle, acceptance, and operator wrappers |
| CI workflows | Gitea, GitHub, generic, or none, according to setup options |
| `AGENTS.md` | Explicit deployment contract for automation and LLM agents |

Secret values are never generated into tracked files.

Re-running setup updates generator-owned files only while they remain unchanged. Local modifications are preserved and proposed replacements are written under `.arcturus/updates/`. `--force` creates a timestamped backup before replacement. `.arcturus/project.json` is always project-owned and is never overwritten automatically.

## Build graph

`.arcturus/project.json` maps build outputs to release components. One image digest may serve multiple components such as `web` and `db-init`; CI builds and pushes it once. Fixed infrastructure components must already use immutable digests.

Validation targets run before release targets in isolated job-local Buildah storage. The runner does not need the application's language toolchain when tests are expressed as Containerfile validation stages.

For a declarative multi-component example, see [`examples/projects/stellar-like`](examples/projects/stellar-like). For a shared image plus one-shot asset export, see [`examples/projects/web-with-assets`](examples/projects/web-with-assets).

## Service types

- `web` — long-running HTTP service; can be public, internal, or host-bound.
- `worker` — long-running background process or queue consumer.
- `scheduled` — one-shot container invoked by a generated systemd timer.
- `oneshot` — migration, initialization, seeding, or asset-export dependency.

All types use the same release manifest, deployment API, state store, secret model, verification, and rollback path.

## First deployment

1. Add separate `REGISTRY_USER`, `REGISTRY_TOKEN`, and `ARCTURUS_DEPLOY_TOKEN` values to protected CI secret storage.
2. Confirm the Arcturus bundle reference in `.arcturus/lock.env` is an immutable digest.
3. Push to the protected deployment branch.
4. CI runs `scripts/arcturus-guard`, validates build targets, pushes full-commit image tags, resolves digests, renders the release, deploys, and verifies active commit/images/health/routing.
5. Inspect runtime state from a trusted host:

```bash
export ARCTURUS_API_URL='http://127.0.0.1:9090'
export ARCTURUS_TOKEN_FILE="$HOME/.config/arcturus/my-api.token"
./scripts/arcturus-service status
systemctl --user status arcturus-my-api.target
journalctl --user -u 'arcturus-my-api-*' --since today
```

An update is another immutable release. The deployer reports success only after all required services, one-shots, timers, health checks, and routing verification have passed.

## Lifecycle

```bash
./scripts/arcturus-service status
./scripts/arcturus-service rollback
./scripts/arcturus-service rollback --deployment-id '<known-good-id>'
./scripts/arcturus-service disable
./scripts/arcturus-service enable
./scripts/arcturus-service remove
```

`remove` withdraws generated runtime ownership and routing, but preserves release archives, audit data, Podman secrets, bind-mounted data, and named volumes.

## Acceptance

The manual CI acceptance workflow submits a deliberately unhealthy same-image release and requires failed promotion, successful automatic rollback, and restoration of the original revision, digests, and route. It does not reboot the host or operate backups.

Host operators use `scripts/arcturus-host-acceptance` for backup-gated reboot verification and must explicitly name critical units.

## Documentation

- [Documentation index](docs/README.md)
- [Blueprint architecture](docs/architecture.md)
- [Project configuration reference](docs/project-reference.md)
- [Secrets](docs/secrets.md)
- [Operations and troubleshooting](docs/operations.md)
- [Migration](docs/migration.md)
- [Extending generated projects](docs/extensions.md)

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md). The project is licensed under the [Apache License 2.0](LICENSE).
