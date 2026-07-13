# Arcturus deployment contract for automation and LLM agents

Read `.arcturus/project.json` and `arcturus.release.json` before changing builds, deployment, routing, lifecycle, Terraform, Compose, or secrets. `arcturus.release.json` is the only deployment manifest. `.arcturus/project.json` is the project-owned build and verification graph.

Use exactly this production path:

1. Run `scripts/arcturus-guard`.
2. Run `scripts/arcturus-ci <full-40-character-commit>` from CI, or use the commands it wraps: `arcturusctl project validate`, `project plan`, `project render`, `project deploy`, then `project verify`.
3. Build every declared validation target before its release target in isolated job-local Buildah storage.
4. Push only full-commit tags, resolve registry digests, and render every component as `repository@sha256:digest`.
5. One build may map its digest to several components. Never rebuild or retag shared-image consumers such as `web` and `db-init`. Fixed infrastructure components retain their declared digests.
6. Treat success as active commit + exact images + healthy units + a matching published router receipt. Nginx is generated from the published active manifest.

Every routed component joins `internal_routing`; its route port is the container’s listening port. Do not publish a public host port or create an application-owned nginx file. TLS terminates at the configured portal. A Cloudflare challenge is successful verification only when the project policy explicitly says `cloudflare-challenge`.

Use `scripts/arcturus-lifecycle` for status, rollback, enable, disable, or remove. Use the manual acceptance workflow for the expected HTTP 502 rollback probe. CI never runs backups or reboots; those are host-local `scripts/arcturus-host-acceptance` operations with explicit confirmation and declared critical units.

Forbidden:

- Legacy `/deploy`, direct deployment curl, `latest`, Watchtower, or production Compose.
- Terraform application release ownership, `null_resource`, `local_file`, Git reset, or shell container replacement.
- Shared/global runner pruning or storage. Buildah roots, auth, token, and cleanup belong to one job.
- `DEPLOY_WEBHOOK_SECRET`, `REGISTRY_PASSWORD`, bearer tokens in arguments, embedded Git credentials, or secret-like manifest environment values.
- Manual nginx edits or a routed component missing `internal_routing`.

If the runner lacks the application toolchain, tests belong in a declared Containerfile validation target. Preserve `.arcturus/project.json` and customized manifests on blueprint reruns; review staged proposals beneath `.arcturus/updates/`.
