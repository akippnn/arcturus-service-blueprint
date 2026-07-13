# Security policy

## Reporting

Do not open a public issue for a vulnerability or exposed credential. Use the repository host's private security-advisory feature or a private maintainer contact.

Include the affected blueprint version, generated file, setup options, reproduction steps, and impact. Redact tokens, registry auth, private addresses, and host paths.

## Security expectations

- Deployment tokens are service-scoped and stored only in protected CI secret storage or protected token files.
- Registry push credentials are separate from host pull credentials.
- Generated repositories must not commit `.env` files, auth files, deployment responses, or Buildah storage.
- CI runners should not be privileged and should not mount the production host Podman socket.
- Generated workflows use immutable image digests and full 40-character source revisions.

Immediately revoke any credential believed to be exposed. Rewriting history does not revoke a credential.
