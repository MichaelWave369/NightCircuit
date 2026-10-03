from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-005 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/actors/phi_bot/phi_bot.gd",
    [
        'const ACTOR_ID := "phi_bot"',
        '"FOLLOW"',
        '"HOLD"',
        '"LIGHT"',
        '"INSPECT"',
        "LIGHT_DRAIN_PER_SECOND",
        "PASSIVE_RECHARGE_PER_SECOND",
        "INSPECT_COST",
        "get_nodes_in_group",
        "inspect_result",
        "actor_snapshot",
    ],
)

require_tokens(
    "game/input/human_input_adapter.gd",
    [
        "INPUT_PHI_FOLLOW",
        "INPUT_PHI_HOLD",
        "INPUT_PHI_LIGHT",
        "INPUT_PHI_INSPECT",
        '_submit(phi_actor_id, "FOLLOW"',
        '_submit(phi_actor_id, "HOLD"',
        '_submit(phi_actor_id, "LIGHT"',
        '_submit(phi_actor_id, "INSPECT"',
    ],
)

adapter = (ROOT / "game/input/human_input_adapter.gd").read_text(encoding="utf-8")
for forbidden in (
    "$PhiBot",
    "phi_bot.",
    "energy =",
    "global_position =",
    "_light_enabled =",
):
    if forbidden in adapter:
        print(f"Human input adapter bypasses Φ-Bot boundary: {forbidden}")
        sys.exit(1)

require_tokens(
    "game/world/inspection/inspectable.gd",
    [
        "inspection_id",
        "inspection_record",
        "confidence",
        "category",
    ],
)

# Preserve embodied Φ-Bot and inspectable capabilities, not a milestone label.
require_tokens(
    "game/main/Main.tscn",
    [
        "PhiBot.tscn",
        'name="PhiBot"',
        "Inspectable.tscn",
        "ImpossibleDoorTrace",
        "VigilCacheTrace",
        "PhiState",
        "InspectionState",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "phi_bot.bind_hunter",
        "phi_bot.inspect_result.connect",
        "_on_phi_inspect_result",
        "_update_phi_readout",
    ],
)

authority = (ROOT / "protocol/authority/authority_gate.gd").read_text(encoding="utf-8")
for action in ('"FOLLOW"', '"HOLD"', '"LIGHT"', '"INSPECT"'):
    if action not in authority:
        print(f"Authority gate missing Φ-Bot action: {action}")
        sys.exit(1)

print("NC-005 Φ-Bot contract validation: PASS")
