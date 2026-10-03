from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

bridge_path = ROOT / "protocol/pixelforge/runtime_bridge_v1.gd"
project_path = ROOT / "project.godot"
test_path = ROOT / "tests/qualification/pixelforge_bridge_smoke.gd"

for path in [bridge_path, project_path, test_path]:
    if not path.exists():
        print(f"NC-018 missing required file: {path.relative_to(ROOT)}")
        sys.exit(1)

bridge = bridge_path.read_text(encoding="utf-8")
required_methods = [
    "func describe()",
    "func registerController(",
    "func observe(",
    "func submit(",
    "func advance(",
    "func events(",
    "func snapshot()",
    "func recording()",
    "func authority()",
    "func hash()",
]
missing = [token for token in required_methods if token not in bridge]
if missing:
    print("NC-018 bridge contract incomplete:")
    for token in missing:
        print(f"  - {token}")
    sys.exit(1)

required_tokens = [
    'const BRIDGE_PROTOCOL := "pixelforge-runtime-bridge"',
    'const BRIDGE_VERSION := 1',
    '"deterministic": false',
    '"clockMode": "engine"',
    '"advanceSemantics": "flush-controller-batch"',
    '"DELEGATE_CONTROLLER"',
    '"bridge_authority_denied"',
]
missing_tokens = [token for token in required_tokens if token not in bridge]
if missing_tokens:
    print("NC-018 bridge semantics incomplete:")
    for token in missing_tokens:
        print(f"  - {token}")
    sys.exit(1)

project = project_path.read_text(encoding="utf-8")
if 'PixelForgeBridge="*res://protocol/pixelforge/runtime_bridge_v1.gd"' not in project:
    print("NC-018 PixelForgeBridge autoload missing.")
    sys.exit(1)

test = test_path.read_text(encoding="utf-8")
for token in [
    'bridge.registerController({',
    '"script:pixelforge"',
    '"ACTION_REJECTED"',
    '"AUTHORITY_DELEGATED"',
    'receipts.latest_decision()',
]:
    if token not in test:
        print(f"NC-018 executable smoke missing proof token: {token}")
        sys.exit(1)

print("NC-018 PixelForge runtime bridge validation: PASS")
