from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-002 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/actors/hunter/hunter.gd",
    [
        "move_and_slide()",
        "COYOTE_TIME",
        "JUMP_BUFFER_TIME",
        "LEDGE_HANG",
        "_try_begin_ledge_grab",
        "_perform_wall_kick",
        "_set_crouched",
        '"MOVE"',
        '"JUMP"',
        '"CROUCH"',
    ],
)

require_tokens(
    "game/input/human_input_adapter.gd",
    [
        'get_node_or_null("/root/ActionBus")',
        '"MOVE"',
        '"JUMP"',
        '"CROUCH"',
        "InputMap",
    ],
)

adapter = (ROOT / "game/input/human_input_adapter.gd").read_text(encoding="utf-8")
for forbidden in ("$Hunter", "velocity =", "global_position ="):
    if forbidden in adapter:
        print(f"Human input adapter bypasses actor boundary: {forbidden}")
        sys.exit(1)

# NC-002 originally used a one-screen MovementLab in Main.tscn. NC-003
# intentionally replaces that temporary scaffold with the sewer traversal world.
# Preserve the real NC-002 invariant: the Hunter still has collidable traversal
# geometry available for ledge and wall movement, regardless of which scene owns it.
main_scene = (ROOT / "game/main/Main.tscn").read_text(encoding="utf-8")
world_scene = (ROOT / "game/world/sewer_test/SewerTestRoom.tscn")
world_script = (ROOT / "game/world/sewer_test/sewer_test_room.gd")

has_legacy_movement_lab = (
    'name="LedgeBlock"' in main_scene
    and 'type="StaticBody2D"' in main_scene
)

has_sewer_traversal_world = (
    world_scene.is_file()
    and world_script.is_file()
    and "GEOMETRY" in world_script.read_text(encoding="utf-8")
    and "_make_static_rect" in world_script.read_text(encoding="utf-8")
)

if not (has_legacy_movement_lab or has_sewer_traversal_world):
    print("NC-002 requires collidable traversal geometry for ledge/wall movement.")
    sys.exit(1)

require_tokens(
    "protocol/authority/authority_gate.gd",
    [
        '"MOVE"',
        '"JUMP"',
        '"CROUCH"',
        '"LEDGE_GRAB"',
        '"WALL_KICK"',
    ],
)

print("NC-002 movement contract validation: PASS")
