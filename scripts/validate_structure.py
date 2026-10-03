from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "project.godot",
    "game/main/Main.tscn",
    "game/main/main.gd",
    "game/input/human_input_adapter.gd",
    "game/protocol/runtime_observation_provider.gd",
    "game/reality/reality_ledger.gd",
    "game/actors/hunter/hunter.gd",
    "game/actors/hunter/Hunter.tscn",
    "game/actors/phi_bot/phi_bot.gd",
    "game/actors/phi_bot/PhiBot.tscn",
    "game/actors/enemies/drain_husk/drain_husk.gd",
    "game/actors/enemies/drain_husk/DrainHusk.tscn",
    "game/actors/bosses/the_fallen/the_fallen.gd",
    "game/actors/bosses/the_fallen/TheFallen.tscn",
    "game/combat/hitbox.gd",
    "game/combat/hurtbox.gd",
    "game/world/sewer_test/sewer_test_room.gd",
    "game/world/sewer_test/SewerTestRoom.tscn",
    "game/world/inspection/inspectable.gd",
    "game/world/inspection/Inspectable.tscn",
    "game/world/ash_village/ash_village.gd",
    "game/world/ash_village/AshVillage.tscn",
    "game/world/fallen_arena/fallen_arena.gd",
    "game/world/fallen_arena/FallenArena.tscn",
    "game/actors/npc/village_npc.gd",
    "game/actors/npc/VillageNpc.tscn",
    "protocol/actions/action_contract.gd",
    "protocol/adapters/adapter_contract.gd",
    "protocol/action_bus/action_bus.gd",
    "protocol/authority/authority_gate.gd",
    "protocol/observations/observation.gd",
    "protocol/player_protocol.gd",
    "protocol/receipts/receipt_ledger.gd",
    "protocol/transports/local_agent_server.gd",
    "tools/p3_client.py",
    "tools/p3_ollama_agent.py",
    "docs/GAME_DESIGN.md",
    "docs/PLAYER_PROTOCOL.md",
    "docs/ADAPTERS.md",
    "docs/AGENT_SEAT.md",
    "docs/ARCHITECTURE.md",
    "docs/MOVEMENT.md",
    "docs/WORLD_FLOW.md",
    "docs/COMBAT.md",
    "docs/PHI_BOT.md",
    "docs/ACTION_BUS.md",
    "docs/VERTICAL_SLICE.md",
    "docs/ROADMAP.md",
    "docs/REALITY_LEDGER.md",
    "docs/THE_FALLEN.md",
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
    'PlayerProtocol="*res://protocol/player_protocol.gd"',
    'RealityLedger="*res://game/reality/reality_ledger.gd"',
):
    if autoload not in project:
        print(f"Missing autoload contract: {autoload}")
        sys.exit(1)

authority = (ROOT / "protocol/authority/authority_gate.gd").read_text(encoding="utf-8")
if "CAPABILITY != AUTHORITY" not in authority:
    print("Authority invariant marker missing.")
    sys.exit(1)

protocol = (ROOT / "docs/PLAYER_PROTOCOL.md").read_text(encoding="utf-8")
for marker in (
    "phi-player-protocol/message/0.3",
    "phi-player-protocol/response/0.3",
    "phi-player-protocol/observation/0.3",
    "describe",
    "observe",
    "act",
    "request_id",
):
    if marker not in protocol:
        print(f"Player Protocol is missing required contract marker: {marker}")
        sys.exit(1)

print("Night Circuit structure validation: PASS")
