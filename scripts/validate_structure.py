from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "project.godot",
    "game/main/Main.tscn",
    "game/main/main.gd",
    "game/input/human_input_adapter.gd",
    "game/actors/hunter/hunter.gd",
    "game/actors/hunter/Hunter.tscn",
    "game/actors/phi_bot/phi_bot.gd",
    "game/actors/phi_bot/PhiBot.tscn",
    "game/actors/enemies/drain_husk/drain_husk.gd",
    "game/actors/enemies/drain_husk/DrainHusk.tscn",
    "game/combat/hitbox.gd",
    "game/combat/hurtbox.gd",
    "game/world/sewer_test/sewer_test_room.gd",
    "game/world/sewer_test/SewerTestRoom.tscn",
    "game/world/inspection/inspectable.gd",
    "game/world/inspection/Inspectable.tscn",
    "protocol/actions/action_contract.gd",
    "protocol/action_bus/action_bus.gd",
    "protocol/authority/authority_gate.gd",
    "protocol/observations/observation.gd",
    "protocol/receipts/receipt_ledger.gd",
    "docs/GAME_DESIGN.md",
    "docs/PLAYER_PROTOCOL.md",
    "docs/ARCHITECTURE.md",
    "docs/MOVEMENT.md",
    "docs/WORLD_FLOW.md",
    "docs/COMBAT.md",
    "docs/PHI_BOT.md",
    "docs/ACTION_BUS.md",
    "docs/VERTICAL_SLICE.md",
    "docs/ROADMAP.md",
]

missing = [path for path in REQUIRED if not (ROOT / path).is_file()]
if missing:
    print("Missing required Night Circuit files:")
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

print("Night Circuit structure validation: PASS")
