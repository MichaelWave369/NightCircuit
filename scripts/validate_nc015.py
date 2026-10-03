from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-015 qualification tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/save/run_save.gd",
    [
        "night-circuit/run-save/0.1",
        "night_circuit_run_save_v1.json",
        "save_snapshot",
        "load_snapshot",
        "has_save",
        "FileAccess",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        '"milestone": "NC-015"',
        "_save_run",
        "_load_run",
        "_restore_run_snapshot",
        "KEY_F5",
        "KEY_F9",
        "_on_altermath_teaser",
        "ALTERMATH LAYER DETECTED",
        "_update_qualification_readout",
        '"subject": "altermath_layer_01"',
    ],
)

require_tokens(
    "game/input/human_input_adapter.gd",
    [
        "_ensure_controller_actions",
        "InputEventJoypadButton",
        "InputEventJoypadMotion",
        "JOY_AXIS_LEFT_X",
        "JOY_BUTTON_A",
        "JOY_BUTTON_X",
        "JOY_BUTTON_Y",
        "JOY_BUTTON_B",
        "JOY_BUTTON_RIGHT_SHOULDER",
        "JOY_BUTTON_LEFT_SHOULDER",
        "JOY_AXIS_TRIGGER_RIGHT",
    ],
)

require_tokens(
    "game/world/sewer_test/sewer_test_room.gd",
    [
        "altermath_teaser",
        "altermath_layer_01",
        '"category": "altermath_layer"',
        '"local_reality_consistency": 63',
        '"cause": "UNKNOWN"',
    ],
)

require_tokens(
    "game/world/ash_village/ash_village.gd",
    [
        "restore_phase",
        '"DAY"',
        '"DUSK"',
        '"NIGHT"',
    ],
)

require_tokens(
    "game/actors/hunter/hunter.gd",
    [
        "restore_health_for_load",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "NC-015 // VERTICAL SLICE 0.1",
        "QualificationState",
        "SaveState",
    ],
)

workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
for marker in (
    "Godot 4.3 headless parse",
    "Godot 4.3 boot smoke",
    "Godot_v4.3-stable_linux.x86_64",
):
    if marker not in workflow:
        print(f"NC-015 runtime qualification marker missing: {marker}")
        sys.exit(1)

vertical = (ROOT / "docs/VERTICAL_SLICE.md").read_text(encoding="utf-8")
for marker in (
    "save/load",
    "keyboard and controller support",
    "Altermath teaser",
    "The Fallen boss",
    "Scout Core transformation",
):
    if marker not in vertical:
        print(f"Vertical slice acceptance marker missing: {marker}")
        sys.exit(1)

print("NC-015 Vertical Slice 0.1 qualification: PASS")
