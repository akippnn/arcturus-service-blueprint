# Pre-push image-size policy

Generated Arcturus CI rejects oversized release images before any registry upload.

The default local ceiling is **805,306,368 bytes (768 MiB) per release image**. Override it with a positive integer when a project has a reviewed reason to use another limit:

```bash
export ARCTURUS_MAX_IMAGE_SIZE_BYTES=805306368
```

The policy runs after the release target is built and before `buildah push`. CI records the measured uncompressed local image size and the configured ceiling. A rejected image exits with status `3` without sending its layers to the registry.

After the local check, CI submits only the service name, image reference, and measured byte count to the authenticated Arcturus `/v1/image-policy` endpoint. A host running the `image-size-policy` capability may impose its own ceiling and reject the upload with HTTP `413`.

Older Arcturus hosts return HTTP `404`; CI then retains the local fail-safe ceiling. Authentication errors, policy-service failures, and network failures fail closed rather than starting a registry upload.

Projects should still minimize runtime images through multi-stage builds, production-only dependencies, and framework-specific standalone output. Raising either limit is not a substitute for correcting an accidentally bundled dependency tree or build toolchain.
