# Migrating Compose- or Terraform-driven services

1. Inventory containers, networks, host ports, bind mounts, named volumes, secrets, dependencies, health checks, and router metadata. Back up persistent data and record the current image digest.
2. Bootstrap the repository and translate Compose services into v2 components. Record the build graph in `.arcturus/project.json`, including shared digests (for example `web` plus `db-init`) and fixed infrastructure digests. Adopt existing bind paths and external named volumes—including Compose names containing underscores—in place; never create a replacement with the same name blindly.
3. Provision Podman secrets on the host and replace secret values or `.env` interpolation with manifest references.
4. Keep Terraform only for long-lived host/network resources. Remove release `null_resource`, generated Compose files, Git reset, and container-replacement provisioners only after cutover. Remove resources from state without invoking destructive provisioners where required.
5. Preserve internal application networks needed for database/cache traffic, but every routed component must also join `internal_routing`. Make migration/init one-shots idempotent, order them through `dependsOn`, and ensure a rerun against an already-migrated database succeeds safely.
6. Render and validate a digest-pinned release. For public web services, confirm the active v2 routing metadata matches the existing domain and container port and wait for a matching router receipt rather than editing nginx.
7. Before database migrations, record a rollback checkpoint: current deployment ID/digests, schema version, backup result, role/secret versions, and volume identity. Keep old runtime credentials usable by the previous-known-good release.
8. Stop Compose/Watchtower ownership during a maintenance window, deploy through Arcturus, validate health, migrations, adopted data, and route receipt, then reboot-test declared critical units.
9. Deliberately deploy an unhealthy test release and prove automatic rollback restores the known-good digest and route. Complete two successful releases on new database credentials before revoking the old rollback credential.
10. Retain Compose only for local development or documented emergency compatibility. Do not let Compose, Watchtower, and Quadlet own the same production container concurrently.

Migrate low-risk stateless services before multi-component or critical data services. Retired services remain retired.
