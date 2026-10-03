from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-010 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/world/ash_village/ash_village.gd",
    [
        'DEFAULT_PHASE := "DUSK"',
        "REALITY_CONSISTENCY",
        '"DAY": 96',
        '"NIGHT": 81',
        "phase_changed",
        "ring_bell",
        "_next_phase",
        "NIGHT_GEOMETRY",
        "NIGHT_SPAWNS",
        "DrainHuskScene",
        "_set_night_geometry",
        "_sync_night_hostiles",
        "world_state_snapshot",
        "shop_state",
        "night_route_discontinuity",
    ],
)

require_tokens(
    "game/actors/npc/village_npc.gd",
    [
        "apply_phase",
        "current_phase",
        "_schedules",
        "_presence_by_phase",
        "_testimony_by_phase",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "WorldState",
        "NC-010 // DAY / NIGHT",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "phase_changed.connect",
        "_on_phase_changed",
        "_update_world_state_readout",
        "BELL EVENT",
        "REALITY",
    ],
)

require_tokens(
    "game/protocol/runtime_observation_provider.gd",
    [
        "world_state",
        "_world_state_snapshot",
        "is_visible_in_tree",
    ],
)

print("NC-010 day/night validation: PASS")
