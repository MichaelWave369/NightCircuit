from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-006 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "protocol/actions/action_contract.gd",
    [
        "night-circuit/action/0.2",
        "DECISION_RECEIPT_SCHEMA",
        "EFFECT_RECEIPT_SCHEMA",
        "request_id",
        "replay_of",
        "validate_effect_result",
        "EFFECT_STATUSES",
    ],
)

require_tokens(
    "protocol/action_bus/action_bus.gd",
    [
        "register_actor",
        "unregister_actor",
        "submit_replay_entry",
        "_dispatch",
        "_decision_receipt",
        "_effect_receipt",
        "duplicate_request_id",
        "effect_recorded",
    ],
)

require_tokens(
    "protocol/receipts/receipt_ledger.gd",
    [
        "latest_decision",
        "latest_effect",
        "receipts_for_action",
        "replay_tape",
        "night-circuit/replay-entry/0.1",
    ],
)

for actor_path in (
    "game/actors/hunter/hunter.gd",
    "game/actors/phi_bot/phi_bot.gd",
):
    require_tokens(
        actor_path,
        [
            "register_actor",
            "execute_action",
            '"status"',
            '"reason"',
            '"effect"',
        ],
    )

require_tokens(
    "game/main/main.gd",
    [
        '"decision"',
        '"effect"',
        "_last_decision",
        "_last_effect",
        "_update_replay_readout",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "ReceiptLabel",
        "ReplayState",
        "EFFECT RECEIPTS",
    ],
)

action_bus = (ROOT / "protocol/action_bus/action_bus.gd").read_text(encoding="utf-8")
if "action_accepted.emit" not in action_bus:
    print("NC-006 must preserve accepted-action observer signal.")
    sys.exit(1)

hunter = (ROOT / "game/actors/hunter/hunter.gd").read_text(encoding="utf-8")
phi_bot = (ROOT / "game/actors/phi_bot/phi_bot.gd").read_text(encoding="utf-8")
for actor_text, actor_name in ((hunter, "Hunter"), (phi_bot, "PhiBot")):
    if 'connect("action_accepted"' in actor_text:
        print(f"{actor_name} still uses global accepted-action signal as execution transport.")
        sys.exit(1)

print("NC-006 action lifecycle validation: PASS")
