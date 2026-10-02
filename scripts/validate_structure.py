from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "project.godot",
    "game/main/Main.tscn",
    "game/main/main.gd",
    "game/actors/hunter/hunter.gd",
    "game/actors/phi_bot/phi_bot.gd",
    "protocol/action_bus/action_bus.gd",
    "protocol/authority/authority_gate.gd",
    "protocol/observations/observation.gd",
    "protocol/receipts/receipt_ledger.gd",
    "docs/GAME_DESIGN.md",
    "docs/PLAYER_PROTOCOL.md",
    "docs/ARCHITECTURE.md",
    "docs/VERTICAL_SLICE.md",
    "docs/ROADMAP.md",
]

missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
if missing:
    print("Missing required NC-001 files:")
    for path in missing:
        print(f"  - {path}")
    sys.exit(1)

project = (ROOT / "project.godot").read_text(encoding="utf-8")
for autoload in (
    'ActionBus="*res://protocol/action_bus/action_bus.gd"',
    'AuthorityGate="*res://protocol/authority/authority_gate.gd"',
    'ReceiptLedger="*res://protocol/receipts/receipt_ledger.gd"',
):
    if autoload not in project:
        print(f"Missing autoload contract: {autoload}")
        sys.exit(1)

authority = (ROOT / "protocol/authority/authority_gate.gd").read_text(encoding="utf-8")
if "CAPABILITY != AUTHORITY" not in authority:
    print("Authority invariant marker missing.")
    sys.exit(1)

protocol = (ROOT / "docs/PLAYER_PROTOCOL.md").read_text(encoding="utf-8")
for token in ("source", "actor", "action", "payload", "accepted", "reason"):
    if f"`{token}`" not in protocol and f'"{token}"' not in protocol:
        print(f"Player Protocol is missing required token: {token}")
        sys.exit(1)

print("NC-001 structure validation: PASS")
