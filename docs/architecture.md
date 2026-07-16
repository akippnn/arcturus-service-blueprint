# Blueprint architecture

The service blueprint converts application repository intent into a concrete Arcturus release without taking host lifecycle ownership itself.

## Files and owners

| File or area | Owner | Role |
| --- | --- | --- |
| Application source and Containerfiles | project | Build inputs and tests |
| `.arcturus/project.json` | project | Build graph, component mapping, CI/registry settings, and verification policy |
| `arcturus.release.json` | project | Release template with components, networks, secrets, volumes, dependencies, schedules, and routes |
| `.arcturus/lock.env` | project/release manager | Immutable control-plane bundle and schema lock |
| Generated scripts/workflows | blueprint while unchanged | Reusable CI and lifecycle adapters |
| `.arcturus/updates/` | generator | Proposed replacements for locally modified files |
| Host Quadlets/state | Arcturus | Never authored or committed by the application repository |

## CI flow

```text
scripts/arcturus-guard
        |
        v
validate build graph and release template
        |
        v
Buildah validation targets -> release targets -> registry push
        |
        v
resolve image digests and render all components
        |
        v
arcturusctl project deploy
        |
        v
arcturusctl project verify
```

Buildah storage, registry auth, and deployment-token files are job-local. Cleanup traps explicitly remove working containers, prune only the job-local Buildah root, and delete the run directory on success, failure, or cancellation. Shared-image consumers reuse one resolved digest.

## Verification contract

A deployment is accepted only when the host reports:

- the expected source revision
- the exact image digest for every component
- required services/timers/one-shots in accepted states
- successful health checks when configured
- a matching router receipt when public routing is required

The blueprint does not treat a successful HTTP request alone as a successful deployment.

## Generator ownership

The setup script hashes generated files. An untouched file can be upgraded automatically; a modified file is preserved and the new version is staged under `.arcturus/updates/`. This avoids erasing project-specific logic while still making blueprint updates visible.

Project-owned build graphs and customized manifests are never overwritten.
