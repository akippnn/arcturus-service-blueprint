# Changelog

## [0.99.0-rc.2] - 2026-07-15

### Added

- Replayable project bootstrap and update workflow with blueprint provenance, normalized setup intent, and append-only update history
- Machine-readable compatibility metadata and generated minimum-host capability locks
- Authenticated host preflight before expensive application image builds
- Declarative legacy Compose migration support in project specifications
- Compatibility and project-update documentation for RC1 adoption and older deployment generations

### Changed

- Generated workflows support an explicit registry username while retaining GitHub and Gitea actor fallback
- Build execution prefers isolated Buildah storage before Podman fallback
- Setup validation isolates optional cross-repository host-installer testing from normal blueprint validation
- Generated workflow names and deployment diagnostics are clearer and consistent across GitHub and Gitea

## [0.99.0-rc.1] - 2026-07-13

### Added

- Public bootstrap flow for web, worker, scheduled, one-shot, and multi-component projects
- Project-owned build graph with shared-image component mappings and fixed components
- Digest-pinned tool lock, CI adapters, lifecycle commands, rollback acceptance, and host acceptance helpers
- Generator ownership tracking and non-destructive update staging
- Public architecture, project-reference, security, operations, migration, and extension documentation
- GitHub-native validation and secret-scanning workflows
- Tag-gated GitHub release packaging and monthly dependency-update configuration

### Changed

- Public examples use documentation-only addresses and generic project names
- GitHub/Gitea checkout actions are pinned to reviewed commits

### Removed

- Obsolete Terraform-directory validation from the blueprint security workflow
