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
| `compatibility` | Supported manifest APIs and optional v1 routing mirror |

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

External-registry mode preserves an existing Gitea Packages, GHCR, or other OCI publisher:

```json
{
  "mode": "external",
  "host": "registry.example.org",
  "userSecret": "REGISTRY_USER",
  "tokenSecret": "REGISTRY_TOKEN"
}
```

Use a push-limited CI credential. The production host uses a separate pull-only credential. Gitea and GitHub are both supported; the registry does not need to match the CI provider.

Owned-registry mode uses Arcturus's private Tailscale HTTPS origin and short-lived upload grants:

```json
{
  "mode": "owned",
  "host": "arcturus-oci.example.ts.net",
  "origin": "https://arcturus-oci.example.ts.net",
  "userSecret": "REGISTRY_USER",
  "tokenSecret": "REGISTRY_TOKEN"
}
```

The secret-name fields remain for schema compatibility but are not consumed by owned mode. The runner must establish private network reachability before invoking `scripts/arcturus-ci`.

## Builds

```json
{
  "web": {
    "repository": "registry.example.org/team/my-app",
    "context": ".",
    "containerfile": "Containerfile",
    "validationTargets": ["test"],
    "releaseTarget": "runtime",
    "components": ["web", "db-init"],
    "componentRepositories": {
      "web": "arcturus-oci.example.ts.net/my-app/web",
      "db-init": "arcturus-oci.example.ts.net/my-app/db-init"
    }
  }
}
```

- `repository` excludes tags and digests.
- `context` and `containerfile` are repository-relative.
- every `validationTarget` must build successfully before release publication.
- `releaseTarget` identifies the production stage; use `-` only for the final unnamed stage.
- `components` maps one local build to one or more release components.
- `componentRepositories` is generated in owned mode so a shared build is pushed once per component repository and each component receives its own receipt boundary. External mode may omit it and preserve a shared repository.

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

## Compatibility object

```json
{
  "manifestApis": ["arcturus.u128.org/v1", "arcturus.u128.org/v2"],
  "v1Mode": "routing-mirror",
  "v1Manifest": ".arcturus/compat-v1.json"
}
```

Manifest v2 remains authoritative for build, deployment, activation, rollback, and recovery. The optional v1 file is generated from the concrete v2 release for older routing consumers. Existing native v1 projects are preserved by the host and should be bootstrapped to v2 incrementally rather than overwritten.

## Project specification input

`arcturus-setup --project-spec` accepts `arcturus.u128.org/project-spec/v1` and generates both the release manifest and project build graph for complex applications. Use it when a single set of setup flags cannot express the desired components and build mappings.
