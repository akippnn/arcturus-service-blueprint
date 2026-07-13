# Secrets guide

Arcturus distinguishes authentication between systems. Do not reuse one credential for the deployment API, registry, application, and CI.

## Deployment API authentication

Create a service-scoped token on the host. The raw token is written once to a protected file; the host token database stores only a salted scrypt verifier:

```bash
umask 077
arcturusctl token create \
  --database "$HOME/.config/arcturus/tokens.json" \
  --service my-api \
  --token-id my-api-ci-2026-01 \
  --output "$HOME/.config/arcturus/my-api-ci.token"
```

Do not print the file. Transfer it through an approved protected channel, then place its contents in the CI secret named `ARCTURUS_DEPLOY_TOKEN`. The generated driver immediately writes it to a job-local `0600` file, unsets the environment value, and passes only the file path to `arcturusctl`. Delete unnecessary transfer copies according to local policy.

To rotate, create a second token ID, update and verify CI, then revoke the old verifier:

```bash
arcturusctl token revoke \
  --database "$HOME/.config/arcturus/tokens.json" \
  --token-id my-api-ci-2026-01
```

A token scoped to another service must return HTTP 403. The legacy plaintext token-list format remains readable only for migration.

## Container registry credentials

Use separate registry robots: pull-only for the rootless host and push-limited for CI. Read tokens from a protected file or prompt and pass them through stdin into a protected auth file:

```bash
umask 077
auth_file="$HOME/.config/containers/auth.json"
mkdir -p "$(dirname "$auth_file")"
read -rsp 'Registry token: ' REGISTRY_TOKEN; printf '\n' >&2
printf '%s' "$REGISTRY_TOKEN" | podman login --authfile "$auth_file" \
  --username '<host-pull-robot>' --password-stdin registry.example.org
unset REGISTRY_TOKEN
chmod 600 "$auth_file"
```

Confirm with `podman login --authfile "$auth_file" --get-login registry.example.org` and a digest-pinned pull. Rotate by installing and testing the new robot before revoking the old token. CI uses distinct `REGISTRY_USER` and `REGISTRY_TOKEN` secrets; its job-local auth file is deleted by the cleanup trap and is never uploaded.

## Application/runtime secrets

Create Podman secrets on the rootless host. The manifest contains only the secret name, target, and whether it is exposed as a file or environment variable.

```bash
read -rsp 'Application secret: ' APP_SECRET; printf '\n' >&2
printf '%s' "$APP_SECRET" | podman secret create my-api-signing-key -
unset APP_SECRET
podman secret inspect my-api-signing-key --format '{{.Spec.Name}}'
```

Manifest reference:

```json
{"name":"my-api-signing-key","type":"file","target":"signing-key"}
```

For environment delivery, use `{"name":"my-api-database-url","type":"env","target":"DATABASE_URL"}`. Secret-like keys in ordinary manifest environment values are rejected.

Prefer versioned names such as `my-api-signing-key-v2`. Rotate by creating the new host secret, changing only the manifest reference, deploying and verifying it, then retaining the old name until no rollback release references it. Deployment, rollback, disable, and remove never delete secrets.

For database credentials, create a least-privileged runtime role and a versioned database-URL secret. Keep the old role enabled while deploying the new role, exercise rollback, roll forward, and produce a second successful release using the new role. Only then revoke the old application login; rotate the database-owner password separately. This prevents a nominal rollback from restoring an image that can no longer authenticate.

## CI secrets

Store `ARCTURUS_DEPLOY_TOKEN`, `REGISTRY_USER`, and `REGISTRY_TOKEN` in protected repository or organization secret storage. Restrict deployment workflows to protected branches and trusted runners. Do not enable shell tracing, interpolate secrets into command arguments, append them to tracked or artifacted `.env` files, or upload response/debug bundles containing environment dumps.

Masking is defense in depth, not permission to print values. The generated workflow passes registry tokens through stdin, converts the deployment token to a protected file, and runs the digest-pinned CLI from isolated Buildah storage. Arcturus redacts authorization, token, password, secret, API-key, and registry-auth fields from structured output.

## Host-local files and systemd credentials

`$HOME/.config/arcturus/deployer.env` contains non-secret paths and is mode `0600`. The token database is also `0600`. Back up verifiers and configuration as protected host metadata; the raw CI token belongs in CI, not backups of the application repository.

For other host-service credentials prefer systemd `LoadCredential=` and read from `$CREDENTIALS_DIRECTORY`. Do not put values in unit files, `Environment=`, manifests, Terraform variables/state, or shell arguments. Podman application secrets and systemd host-service credentials solve different problems and should remain separate.

## Git and Tailscale bootstrap credentials

Git remote URLs must never contain a username/token pair. Use a credential helper or SSH agent with a narrowly scoped deploy key, verify `git remote -v` shows a credential-free URL, then revoke any token that previously appeared in configuration or logs.

Treat a Tailscale auth/bootstrap key as one-time enrollment material. Generate a short-lived, tagged, non-reusable key when possible; pass it through the approved host bootstrap channel without tracking or logging it. After `tailscale status` confirms the intended device identity and tags, remove every local copy and revoke the key in the control plane. Ongoing node identity comes from Tailscale state, not a retained bootstrap key.
