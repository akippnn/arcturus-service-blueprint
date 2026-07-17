# Changelog

## [1.0.0-rc.2] - 2026-07-18

### Added

- Provider-neutral Gitea, GitHub, and generic CI driver with provider-correct workflow contexts
- External-registry and Arcturus-owned OCI publishing modes
- Automatic shared-build to per-component repository publication for receipt isolation
- Deterministic manifest-v1 routing mirror generated and checked against authoritative manifest v2
- Incremental adoption guidance for existing native manifest-v1 projects preserved by host-issued runtime provenance
- Replayable project bootstrap/update provenance and capability locks

### Changed

- Manifest v2 remains the only deployment, activation, rollback, and recovery authority
- Gitea workflow concurrency is treated as advisory; host-side service locking is authoritative
- Generated Gitea workflows use an absolute immutable checkout action reference so instance-level action-source settings cannot redirect it
- Owned mode needs only the service-scoped Arcturus control token as a long-lived publisher secret; tailnet enrollment remains project/runner-owned
- Project updates stage a proposed `.arcturus/project.json` when compatibility metadata changes

### Security

- Owned uploads use short-lived repository-scoped credentials and immutable Rust-verified receipts
- V1 compatibility exports carry the exact v2 revision and omit arbitrary nginx configuration; current hosts still derive trusted routing provenance internally
- Native v1 source files retain project ownership while the trusted host registry strips spoofed provenance and supplies a canonical runtime digest plus content-derived revision that the router revalidates
- Full Git revisions are injected as OCI labels and verified before receipt acceptance

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
