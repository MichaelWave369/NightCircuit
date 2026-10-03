from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-009 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/world/ash_village/ash_village.gd",
    [
        "SCHEDULE_SLOT_SECONDS",
        "NPC_PROFILES",
        "Orin",
        "Tamsin",
        "Mara",
        "Nell",
        "bridge_destroyed_long_ago",
        "bridge_present_today",
        "bells_must_not_agree",
        "clock_door_existed",
        "interact_nearest",
        "protocol_entities",
        "protocol_signals",
        "dialogue_presented",
        'exit_requested.emit("sewer")',
    ],
)

require_tokens(
    "game/actors/npc/village_npc.gd",
    [
        "apply_schedule_slot",
        "interaction_record",
        "protocol_record",
        "activity",
    ],
)

require_tokens(
    "game/input/human_input_adapter.gd",
    [
        'INPUT_INTERACT := "nc_interact"',
        '_submit(actor_id, "INTERACT"',
        "KEY_R",
    ],
)

require_tokens(
    "game/actors/hunter/hunter.gd",
    [
        "signal interaction_requested",
        '"INTERACT"',
        "interaction_requested.emit",
        '"interaction_requested"',
    ],
)

require_tokens(
    "game/world/sewer_test/sewer_test_room.gd",
    [
        "AshVillageLift",
        'exit_requested.emit("ash_village")',
        "enter_from_village",
        "set_active",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "AshVillage.tscn",
        'name="AshVillage"',
        "DialogueState",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "_on_world_exit_requested",
        "ash_village.bind_hunter",
        "sewer_world.enter_from_village",
        "runtime_observation_provider.set_world",
        "_on_hunter_interaction_requested",
        "_on_dialogue_presented",
    ],
)

observer = (ROOT / "game/protocol/runtime_observation_provider.gd").read_text(encoding="utf-8")
for token in ("set_world", "protocol_entities", "protocol_signals", "world_phase"):
    if token not in observer:
        print(f"Runtime observation provider missing NC-009 world-routing token: {token}")
        sys.exit(1)

print("NC-009 Ash Village validation: PASS")
