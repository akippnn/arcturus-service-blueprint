# Operations and troubleshooting

## Deployment API credential

`ARCTURUS_DEPLOY_TOKEN` is generated on the Arcturus host, not obtained from Gitea, GitHub, Cloudflare, or another API provider:

```bash
umask 077
arcturusctl token create \
  --database "$HOME/.config/arcturus/tokens.json" \
  --service my-app \
  --token-id my-app-ci \
  --output "$HOME/.config/arcturus/my-app-ci.token"
```

Copy the contents of the output file into the protected CI secret `ARCTURUS_DEPLOY_TOKEN`. The generated deployment workflow performs an authenticated preflight before building application images.

HTTP `401` means the token is missing or invalid. HTTP `403` means it is valid but not scoped to the project service. HTTP `502` with a response body containing `status: failed` means the request authenticated successfully, release activation failed, and Arcturus attempted rollback; inspect the returned `error` and `rollback` fields.

## Status and logs

```bash
./scripts/arcturus-service status
./scripts/arcturus-tool project verify .arcturus/project.json --release release.json
systemctl --user status arcturus-<service>.target
systemctl --user list-units 'arcturus-<service>-*'
journalctl --user -u 'arcturus-<service>-*' --since today
```

Scheduled work is represented by `arcturus-<service>-<component>.timer`; inspect it with `systemctl --user list-timers` and `journalctl` for the corresponding service.

## Common failures

- **No user systemd after logout/reboot:** verify `loginctl show-user <user> -p Linger`, then enable lingering as an administrator.
- **Podman socket unavailable:** check `arcturus-podman-api.service`, `$XDG_RUNTIME_DIR/arcturus/podman.sock`, and rootless Podman storage ownership.
- **Quadlet generator missing:** install the host Podman systemd/Quadlet package. Run the installer with `--validate-only` again.
- **Manifest rejected:** use `arcturusctl validate release.json`; images must be fully qualified `repository@sha256:digest`, dependencies and networks must exist, and secret-like environment keys must use secret references.
- **Project graph rejected:** run `arcturusctl project validate .arcturus/project.json`. Every component must map exactly once to a build or `fixedComponents`; mapped repositories must match, validation/release targets must be valid Containerfile stage names, and fixed images cannot use placeholders.
- **Bind path rejected:** add only the required absolute root to the host allowlist, confirm ownership and SELinux labeling, then restart the deployer. Do not allow `/`.
- **Unit inactive/unhealthy:** inspect the generated unit journal and `podman healthcheck run <container>`. Confirm the health command exists inside the image and listens on the container port.
- **Timer inactive:** validate `OnCalendar` with `systemd-analyze calendar '<expression>'` and inspect the timer unit.
- **Registry pull denied:** refresh the rootless account’s registry login and test the exact digest reference.
- **HTTP 409:** another operation holds the per-service lock. Wait for it to finish; do not delete lock files from a running deployment.
- **HTTP 502:** the requested deployment failed and rollback succeeded. Inspect the returned deployment ID and journals before retrying.
- **HTTP 500:** deployment or rollback failed. Preserve state and release archives; repair the underlying Podman/systemd issue before an explicit rollback.
- **CI appeared green despite failure:** require both a non-error HTTP result and JSON `status == succeeded`. The generated CLI enforces both.
- **CI test command not found:** runners need Bash and Buildah, not the application toolchain. Put tests in a declared Containerfile validation target. The generic driver builds validation targets before release targets and stops before push on failure.
- **Buildah storage collision or disk growth:** verify `ARCTURUS_BUILDAH_ROOT`, `ARCTURUS_BUILDAH_RUNROOT`, `REGISTRY_AUTH_FILE`, and token files are beneath `.arcturus/build/<run>`. Cleanup may remove only that job-local root; never run a shared/global prune from CI.
- **Python/Node host incompatibility:** the control-plane installer requires Python 3.12+, Node 22+, Podman 5.8+, systemd 257+, and the Quadlet generator. Use `install-host.sh --validate-only`; do not redirect units to NVM or a source checkout.
- **Public route missing or deployment times out:** inspect `router-status.json`, registry `/rescan`, registry/router journals, `generated-<service>.conf`, and `podman exec <portal-nginx> nginx -t`. Success requires a receipt whose revision matches the release, with domains, upstreams, configuration digest, and application time. Nginx validation/reload failure is a deployment failure and should restore the previous receipt.
- **Cloudflare returns a challenge:** for protected sites this is expected only when `.arcturus/project.json` uses `publicMode: cloudflare-challenge`. The verifier checks the challenge marker; it does not weaken or bypass Cloudflare policy. Use an authorized browser for application-level acceptance.
- **Rootless sockets disappear after reboot:** verify lingering, `%t/arcturus`, the bus/registry sockets, and service ordering. The host acceptance check should list declared critical units individually.
- **`podman-restart.service` failed but applications recovered:** treat the aggregate unit as diagnostic, not authoritative. Verify each declared critical target/container/timer and its health before declaring an outage.

TLS for `public` services is owned by the existing portal/reverse proxy. The blueprint does not issue certificates. Internal services emit no public routing metadata.

## Recovery safety

Rollback changes only generated Quadlets and the active manifest. Persistent mounts, named volumes, application secrets, and release history are retained. `remove` is deliberately non-destructive. Data deletion requires a separate, explicit storage operation.

## Acceptance and reboot authority

The manually dispatched CI acceptance workflow verifies the active release and router receipt, deploys a same-image release with a deliberately failing readiness check, requires HTTP 502 and successful automatic rollback, then verifies the original deployment ID/digests and route. It never starts backups or reboots.

On the host, first run `scripts/arcturus-host-acceptance status --backup-unit <unit> --critical-unit <unit> ...`. It rejects services started from source/NVM paths and requires the router receipt to match the active manifest; these failures must be repaired before reboot acceptance. Arm the next-boot marker, and only then use the explicitly confirmed reboot command. After boot, run `verify-boot` with the same critical units; the marker is removed only after success.
