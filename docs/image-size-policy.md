# Pre-push image-size policy

Generated Arcturus CI rejects oversized release images before any registry upload.

The default ceiling is **805,306,368 bytes (768 MiB) per release image**. Override it with a positive integer when a project has a reviewed reason to use another limit:

```bash
export ARCTURUS_MAX_IMAGE_SIZE_BYTES=805306368
```

The policy is evaluated after the release target is built and before `buildah push`. The log records the measured uncompressed local image size and the configured ceiling. A rejected image exits with status `3` without sending its layers to the registry.

This is intentionally a pre-push guard. The Arcturus deployment API receives only a digest-pinned release request after registry publication, so it cannot protect a registry from an oversized upload that CI has already started.

Projects should still minimize runtime images through multi-stage builds, production-only dependencies, and framework-specific standalone output. Raising the limit is not a substitute for correcting an accidentally bundled dependency tree or build toolchain.
