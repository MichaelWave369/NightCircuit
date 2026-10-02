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

require_tokens(
    "game/main/Main.tscn",
    [
        "res://game/actors/hunter/Hunter.tscn",
        "res://game/input/human_input_adapter.gd",
        'name="LedgeBlock"',
        'type="StaticBody2D"',
    ],
)

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
