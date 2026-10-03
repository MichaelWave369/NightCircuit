from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-003 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/world/sewer_test/sewer_test_room.gd",
    [
        "INTAKE SHAFT",
        "SPILLWAY",
        "CISTERN APPROACH",
        "CHECKPOINTS",
        "room_changed",
        "checkpoint_changed",
        "respawn_hunter",
        "set_camera_bounds",
        "KILL_Y",
    ],
)

require_tokens(
    "game/actors/hunter/hunter.gd",
    [
        "set_camera_bounds",
        "force_respawn",
        "reset_physics_interpolation",
    ],
)

require_tokens(
    "game/actors/hunter/Hunter.tscn",
    [
        'type="Camera2D"',
        "position_smoothing_enabled = true",
    ],
)

main_scene = (ROOT / "game/main/Main.tscn").read_text(encoding="utf-8")
for required in (
    "SewerTestRoom.tscn",
    "Hunter.tscn",
    "human_input_adapter.gd",
    "ROOM: INTAKE SHAFT",
):
    if required not in main_scene:
        print(f"Main scene missing NC-003 world-flow token: {required}")
        sys.exit(1)

adapter = (ROOT / "game/input/human_input_adapter.gd").read_text(encoding="utf-8")
for forbidden in ("$Hunter", "velocity =", "global_position ="):
    if forbidden in adapter:
        print(f"Human input adapter bypasses actor boundary: {forbidden}")
        sys.exit(1)

print("NC-003 world-flow validation: PASS")
