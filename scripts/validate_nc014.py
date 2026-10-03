from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-014 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/world/sewer_test/sewer_test_room.gd",
    [
        "BACKTRACK_ANCHOR_ID",
        "intake_anchor_01",
        "BACKTRACK_GEOMETRY",
        "SERVICE_VEIN_ID",
        "service_vein_01",
        "protocol_signals",
        "anchor_resonance",
        "apply_scout_mark",
        "backtrack_route_opened",
        "backtrack_discovery",
        "_restore_backtrack_progress",
        "_sync_backtrack_geometry",
        "keyhole_residue_01",
        "world_state_snapshot",
    ],
)

require_tokens(
    "game/actors/phi_bot/phi_bot.gd",
    [
        'has_method("apply_scout_mark")',
        "world_effect",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "backtrack_route_opened.connect",
        "backtrack_discovery.connect",
        "_on_backtrack_route_opened",
        "_on_backtrack_discovery",
        'mark_verified({',
        '"value": "route_open"',
        'record_evidence({',
        '"dedupe_key": "evidence|service_vein_01|discovered"',
        "_update_backtrack_readout",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "BacktrackState",
    ],
)

print("NC-014 backtracking loop validation: PASS")
