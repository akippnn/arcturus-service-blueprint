# Extending generated projects

`arcturus.release.json` is the project’s release template. Add components, dependencies, volumes, secret references, health commands, routes, or schedules directly. CI must provide one immutable image assignment for every component.

Files listed in `.arcturus/managed-files.sha256` are generator-owned only while unchanged. If you edit one, future setup runs preserve it and write the proposed blueprint version under `.arcturus/updates/`. Review with `diff -u`, merge intentionally, then rerun setup. Use `--force` only when a timestamped backup is acceptable.

`.arcturus/project.json`, `.arcturus/project.env`, application source, local Compose, and systemd drop-ins are project/user-owned. The JSON file owns build contexts, validation/release targets, shared component mappings, fixed images, CI secret names, and verification policy; setup never overwrites it. A future schema proposal is staged under `.arcturus/updates/` for review.

Extend host units with drop-ins under `~/.config/systemd/user/<unit>.d/` instead of editing installed unit files. Keep custom components and manifest extensions directly in `arcturus.release.json`; a blueprint rerun stages its simpler proposal rather than erasing the graph. Never place secret values in extension files tracked by Git.
