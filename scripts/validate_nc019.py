from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]

required = [
    ROOT / "tools/pixelforge/package.json",
    ROOT / "tools/pixelforge/p3-runtime-bridge.mjs",
    ROOT / "tools/pixelforge/qualify-night-circuit.mjs",
    ROOT / "tools/pixelforge/qualify-night-circuit-ollama.mjs",
    ROOT / "docs/PIXELFORGE_ASYNC_MODEL_SEAT.md",
]

for path in required:
    if not path.exists():
        print(f"NC-019 missing required file: {path.relative_to(ROOT)}")
        sys.exit(1)

pkg = json.loads((ROOT / "tools/pixelforge/package.json").read_text(encoding="utf-8"))
dep = pkg.get("dependencies", {}).get("parallax-pixelforge", "")
expected_sha = "4cd6c50696612231936f4341e9014a8848fc805d"
if expected_sha not in dep:
    print("NC-019 PixelForge dependency is not pinned to merged Async Host commit.")
    sys.exit(1)

bridge = (ROOT / "tools/pixelforge/p3-runtime-bridge.mjs").read_text(encoding="utf-8")
for token in [
    "createNightCircuitP3BridgeV1",
    "pixelforge-runtime-bridge",
    "flush-controller-batch",
    "tcp-jsonl",
    "phi_bot",
    "ACTION_ACCEPTED",
    "ACTION_REJECTED",
]:
    if token not in bridge:
        print(f"NC-019 P3 bridge missing token: {token}")
        sys.exit(1)

qual = (ROOT / "tools/pixelforge/qualify-night-circuit.mjs").read_text(encoding="utf-8")
for token in [
    "AsyncRuntimeHostV1",
    "createModelPolicyClientV1",
    "createOllamaProviderV1",
    "HOLD",
    "hold_enabled",
    "MODEL_TURN_FAILED",
]:
    if token not in qual:
        print(f"NC-019 qualification missing proof token: {token}")
        sys.exit(1)

print("NC-019 PixelForge async model seat validation: PASS")
