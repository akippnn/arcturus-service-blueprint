#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
if not version:
    raise SystemExit("VERSION is empty")

compatibility = json.loads((ROOT / "COMPATIBILITY.json").read_text(encoding="utf-8"))
checks = {
    "COMPATIBILITY.json blueprintVersion": compatibility.get("blueprintVersion"),
    "COMPATIBILITY.json minimumArcturusVersion": compatibility.get("minimumArcturusVersion"),
}

lock = dict(
    line.split("=", 1)
    for line in (ROOT / ".arcturus/lock.env").read_text(encoding="utf-8").splitlines()
    if line and not line.startswith("#") and "=" in line
)
checks[".arcturus/lock.env ARCTURUS_MIN_VERSION"] = lock.get("ARCTURUS_MIN_VERSION")

for label, value in checks.items():
    if value != version:
        raise SystemExit(f"{label}={value!r}, expected {version!r}")

required_fragments = {
    "README.md": f"`v{version}`",
    "CHANGELOG.md": f"## [{version}]",
    "scripts/arcturus-setup": f"ARCTURUS_MIN_VERSION={version}",
}
for relative, fragment in required_fragments.items():
    text = (ROOT / relative).read_text(encoding="utf-8")
    if fragment not in text:
        raise SystemExit(f"{relative} does not contain {fragment!r}")

manifest_apis = compatibility.get("manifestApis", [])
if manifest_apis != ["arcturus.u128.org/v1", "arcturus.u128.org/v2"]:
    raise SystemExit(f"unexpected compatibility manifest APIs: {manifest_apis!r}")

print(f"Blueprint version metadata is consistent at {version}.")
