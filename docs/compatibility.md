# Blueprint compatibility

## Current generation

- Blueprint: `1.0.0-rc.2`
- Minimum Arcturus host: `1.0.0-rc.2`
- Authoritative deployment API: `arcturus.u128.org/v2`
- Compatibility routing API: `arcturus.u128.org/v1`
- Project API: `arcturus.u128.org/project/v1`
- CI providers: Gitea Actions, GitHub Actions, generic runners, or none
- Registry modes: external registry or Arcturus-owned private OCI ingress

The generated `.arcturus/lock.env` records the exact capabilities required by the selected setup. External registry mode needs the baseline preflight and migration features. Owned mode additionally requires upload grants, artifact verification/receipts, and receipt enforcement. Manifest-v1 mirror mode requires both safe mirror generation and registry-owned v1 provenance routing support.

## Gitea and GitHub

The project scripts are provider-neutral. Generated Gitea workflows use `gitea.sha` and `gitea.event.inputs`; generated GitHub workflows use the corresponding `github.*` contexts. Gitea versions differ in how completely they implement workflow `concurrency`, so correctness never depends on it. The Arcturus host serializes mutations with a per-service lock.

External registry mode works with either provider and preserves the existing `REGISTRY_USER`/`REGISTRY_TOKEN` flow. When the external registry is Gitea Packages, configure a scoped package-write PAT or deploy credential; the generated workflow does not rely on the job `GITEA_TOKEN` for OCI publishing. Owned registry mode also works with either provider and replaces those long-lived push credentials with a short-lived upload grant issued by Arcturus. In owned mode, CI-provider support and network enrollment are deliberately separate: the runner must join or already reside on the tailnet before invoking `scripts/arcturus-ci`. A GitHub project may retain its existing Tailscale action, while a Gitea project may use the same project-owned bootstrap or a tailnet-resident runner.

## Manifest-v1 support

Manifest v1 remains supported for routing consumers, but it is not a second lifecycle authority. The blueprint generates `.arcturus/compat-v1.json` from the concrete digest-pinned manifest-v2 release as a compatibility export for older consumers. Current Arcturus v2 activation converts the accepted v2 release directly into routing state; it does not need to ingest this exported file. The export contains:

- the exact 40-character v2 revision;
- `arcturus.u128.org/compatibility-source=v2`;
- the same routed components, domains, ports, and container names;
- no independently supplied arbitrary nginx directives.

`arcturus-guard` rejects an export that differs from v2. The Arcturus registry also continues to support existing native v1 files: it validates and normalizes recognized fields, strips unknown fields and any authored provenance claims, computes a canonical manifest digest and content-derived revision, and supplies registry-owned v1 provenance that the router independently recomputes before accepting the route. Router enforcement therefore remains enabled by default during upgrades without dropping native v1 routes. Audit mode is only a temporary diagnostic escape hatch for routing sources that bypass the registry.

Native v1 routing receives strict parsing, provenance, bounded values, atomic nginx validation/reload, and routing rollback protections. It cannot provide image receipts, component activation state, or release rollback equivalence because those concepts do not exist in manifest v1. New or bootstrapped projects should retain manifest v2 as lifecycle authority and use v1 only as a routing compatibility surface.

The deprecated Terraform-era `/deploy` endpoint is retained separately for old installations. It now requires service-scoped authentication, a full immutable Git SHA for apply operations, a per-stack lock, exact revision checkout, and an atomic receipt. It still lacks manifest-v2 artifact receipts and complete lifecycle state, so it is compatibility-only rather than safety-equivalent.

## CrownFi-style GitHub adoption

A project that was originally generated for Gitea but now deploys from GitHub should migrate the provider independently from the registry mode. For the lowest-risk first pass, update `.arcturus/project.env` to:

```bash
ARCTURUS_CI=github
ARCTURUS_REGISTRY_MODE=external
ARCTURUS_COMPAT_MANIFEST_V1=true
```

Then apply the newer blueprint in dry-run mode. Keep the project-owned, commit-pinned Tailscale join step already present in the GitHub workflow; the blueprint owns the provider-neutral build, publish, completion, and deploy driver, but it deliberately does not invent a reusable tailnet key, tag, or ACL policy. Modified workflows and scripts are staged beneath `.arcturus/updates/` rather than overwritten.

After the upgraded Arcturus host has passed an existing external-registry deployment, change to `ARCTURUS_REGISTRY_MODE=owned`, set `ARCTURUS_REGISTRY_ORIGIN` to the private Arcturus HTTPS origin, and replay setup again. Owned mode builds shared images once but publishes each component to its own repository and receipt boundary; for example, CrownFi's `api` and `db-init` components may share one build while receiving separate `.../api` and `.../db-init` repositories. No application Containerfile duplication is required.

## Updating existing projects

Projects generated by project-aware 0.99.x releases can use the replayable updater:

```bash
./scripts/arcturus-update apply --from /path/to/arcturus-service-blueprint --dry-run
./scripts/arcturus-update apply --from /path/to/arcturus-service-blueprint
```

Modified files and project-owned `.arcturus/project.json` are preserved. Proposed replacements are staged beneath `.arcturus/updates/`. This lets projects keep the external registry first, adopt the v1 mirror, and enable owned OCI publishing later without one large migration.

Older webhook, Compose, or Terraform-only repositories need one explicit bootstrap because they do not contain durable project intent. Their running service may remain on the legacy path while the generated v2 manifest is validated and adopted.
