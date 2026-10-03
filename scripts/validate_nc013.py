from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-013 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/actors/phi_bot/phi_bot.gd",
    [
        'FORM_SCOUT := "SCOUT"',
        "install_scout_core",
        "RESONANCE_PING",
        "ANCHOR_MARK",
        "ENEMY_READ",
        "CONTRADICTION_SENSE",
        "PING_COST",
        "MARK_COST",
        "SCAN_COST",
        "_execute_ping",
        "_execute_mark",
        "_execute_scan",
        "_enemy_read",
        "_contradiction_read",
        "bind_world",
        "marked_target",
        "contradiction_sense",
        "ability_unavailable_in_broken_form",
    ],
)

require_tokens(
    "game/input/human_input_adapter.gd",
    [
        "INPUT_PHI_PING",
        "INPUT_PHI_SCAN",
        "INPUT_PHI_MARK",
        '_submit(phi_actor_id, "PING"',
        '_submit(phi_actor_id, "SCAN"',
        '_submit(phi_actor_id, "MARK"',
        "KEY_P",
        "KEY_T",
        "KEY_G",
    ],
)

require_tokens(
    "game/world/fallen_arena/fallen_arena.gd",
    [
        "scout_core_claimed",
        "_scout_core_claimed",
        "SCOUT_CORE_CLAIMED",
        "core_id",
        '"form": "SCOUT"',
        "_restore_progress_from_ledger",
    ],
)

require_tokens(
    "game/reality/reality_ledger.gd",
    [
        "has_record",
        "contradiction_sense",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "phi_bot.bind_world",
        "scout_core_claimed.connect",
        "_on_scout_core_claimed",
        "install_scout_core",
        'mark_verified({',
        '"subject": "phi_bot_form"',
        '"value": "SCOUT"',
        "_on_phi_scout_result",
        "_on_phi_form_changed",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "ScoutState",
        "NC-013 // SCOUT CORE",
    ],
)

require_tokens(
    "protocol/actions/action_contract.gd",
    [
        "phi_scan_mode_must_be_string",
        "phi_scan_mode_unsupported",
        "phi_mark_target_must_be_string",
    ],
)

print("NC-013 Scout Core validation: PASS")
