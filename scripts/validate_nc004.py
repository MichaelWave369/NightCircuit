from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-004 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/input/human_input_adapter.gd",
    [
        '"LIGHT_ATTACK"',
        '"HEAVY_ATTACK"',
        '"DODGE"',
        "Input.is_action_just_pressed",
    ],
)

adapter = (ROOT / "game/input/human_input_adapter.gd").read_text(encoding="utf-8")
for forbidden in (
    "$Hunter",
    "velocity =",
    "global_position =",
    "health =",
    "receive_hit(",
):
    if forbidden in adapter:
        print(f"Human input adapter bypasses combat/actor boundary: {forbidden}")
        sys.exit(1)

require_tokens(
    "game/actors/hunter/hunter.gd",
    [
        "enum CombatState",
        "LIGHT_DURATION",
        "HEAVY_DURATION",
        "DODGE_DURATION",
        "receive_hit",
        "restore_full_health",
        "attack_hitbox.activate",
        '"combat"',
        '"health"',
        '"invulnerable"',
    ],
)

require_tokens(
    "game/combat/hitbox.gd",
    [
        "get_overlapping_areas",
        "accept_hit",
        "source_team",
        "_already_hit",
    ],
)

require_tokens(
    "game/combat/hurtbox.gd",
    [
        "source_team",
        "receive_hit",
        "team",
    ],
)

require_tokens(
    "game/actors/enemies/drain_husk/drain_husk.gd",
    [
        "WINDUP",
        "ACTIVE",
        "RECOVERY",
        "receive_hit",
        "attack_hitbox.activate",
        "FloorAheadRay",
    ],
)

# Preserve the NC-004 gameplay invariant, not the old milestone label.
# Later rungs are expected to update HUD/build text while keeping combat live.
require_tokens(
    "game/main/Main.tscn",
    [
        "DrainHusk.tscn",
        "DrainHuskA",
        "DrainHuskB",
        "CombatState",
    ],
)

authority = (ROOT / "protocol/authority/authority_gate.gd").read_text(encoding="utf-8")
for action in ('"LIGHT_ATTACK"', '"HEAVY_ATTACK"', '"DODGE"'):
    if action not in authority:
        print(f"Authority gate missing combat action: {action}")
        sys.exit(1)

print("NC-004 combat contract validation: PASS")
