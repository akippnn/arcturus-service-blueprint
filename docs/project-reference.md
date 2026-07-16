# Project configuration reference

`.arcturus/project.json` uses API `arcturus.u128.org/project/v1`. It describes how CI produces a concrete `ServiceRelease`; it is not submitted to the host as the release manifest.

## Top-level fields

| Field | Purpose |
| --- | --- |
| `apiVersion` | Must be `arcturus.u128.org/project/v1` |
| `service` | Service name; must match release metadata |
| `manifest` | Path to the release template, normally `arcturus.release.json` |
| `ci` | Deployment API and CI behavior |
| `registry` | Registry host and CI secret names |
| `builds` | Build graph keyed by build name |
| `fixedComponents` | Components whose images are not built by this project |
| `verification` | Public URL and routing verification policy |

## CI object

```json
{
  "provider": "github",
  "apiUrl": "http://192.0.2.10:9090",
  "storage": "isolated",
  "deployTokenSecret": "ARCTURUS_DEPLOY_TOKEN",
  "testIntent": {"mode": "command"}
}
```

`apiUrl` should be a loopback or private address reachable only by the trusted runner. `storage` should remain `isolated`. Secret fields name CI secret entries; they do not contain values.

## Registry object

```json
{
  "host": "registry.example.org",
  "transportHost": "registry.internal.example.org:5000",
  "transportTlsVerify": false,
  "userSecret": "REGISTRY_USER",
  "tokenSecret": "REGISTRY_TOKEN"
}
```

Use a push-limited CI credential. The production host uses a separate pull-only credential.
`transportHost` is optional. When set, CI authenticates and pushes through that private
endpoint while release manifests retain the canonical repositories under `host`.
`transportTlsVerify` defaults to `true`; set it to `false` only for a trusted,
network-private HTTP endpoint or an endpoint with a private CA that is not installed
in the runner.

## Builds

```json
{
  "web": {
    "repository": "registry.example.org/team/my-app",
    "context": ".",
    "containerfile": "Containerfile",
    "validationTargets": ["test"],
    "releaseTarget": "runtime",
    "components": ["web", "db-init"]
  }
}
```

- `repository` excludes tags and digests.
- `context` and `containerfile` are repository-relative.
- every `validationTarget` must build successfully before release publication.
- `releaseTarget` identifies the production stage; use `-` only for the final unnamed stage.
- `components` maps the one resolved digest to one or more release components.

Every non-fixed release component must be mapped exactly once.

## Fixed components

Fixed components identify infrastructure images already pinned in the release template. They are not rebuilt or retagged by project CI. Typical examples are PostgreSQL and Redis, but application teams remain responsible for compatibility and update policy.

## Verification

```json
{
  "publicUrl": "https://app.example.org",
  "publicMode": "http-success",
  "requireRouting": true
}
```

Supported public modes are `http-success`, `cloudflare-challenge`, and `skip`. Use `skip` only when the service is intentionally not verifiable from the runner. `requireRouting` requires a revision/deployment-matched router receipt.

## Project specification input

`arcturus-setup --project-spec` accepts `arcturus.u128.org/project-spec/v1` and generates both the release manifest and project build graph for complex applications. Use it when a single set of setup flags cannot express the desired components and build mappings.
