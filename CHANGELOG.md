# Changelog

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
