from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-007 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "protocol/adapters/adapter_contract.gd",
    [
        "phi-player-protocol/message/0.3",
        "phi-player-protocol/response/0.3",
        '"describe"',
        '"observe"',
        '"act"',
        "request_id",
    ],
)

require_tokens(
    "protocol/observations/observation.gd",
    [
        "phi-player-protocol/observation/0.3",
        "observation_id",
        "visible_entities",
        "signals",
        "capabilities",
        "metadata",
    ],
)

require_tokens(
    "protocol/player_protocol.gd",
    [
        "handle_adapter_message",
        "register_observer",
        "unregister_observer",
        "protocol_description",
        "_observe",
        "_act",
        'get_node_or_null("/root/ActionBus")',
        'get_node_or_null("/root/AuthorityGate")',
        'get_node_or_null("/root/ReceiptLedger")',
    ],
)

require_tokens(
    "game/protocol/runtime_observation_provider.gd",
    [
        '"hunter"',
        '"phi_bot"',
        "visible_entities",
        "protocol_capabilities",
        "get_nodes_in_group",
        "protocol_signal",
        "visibility_policy",
    ],
)

require_tokens(
    "game/actors/hunter/hunter.gd",
    ["protocol_capabilities"],
)

require_tokens(
    "game/actors/phi_bot/phi_bot.gd",
    [
        "protocol_capabilities",
        '"PING"',
        "ability_unavailable_in_broken_form",
    ],
)

require_tokens(
    "game/world/inspection/inspectable.gd",
    [
        "protocol_signal",
        "relative_position",
    ],
)

require_tokens(
    "protocol/authority/authority_gate.gd",
    [
        "is_source_allowed",
        "actions_for_actor",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "runtime_observation_provider.bind",
        "handle_adapter_message",
        '"observe"',
        '"describe"',
        "KEY_O",
    ],
)

project = (ROOT / "project.godot").read_text(encoding="utf-8")
if 'PlayerProtocol="*res://protocol/player_protocol.gd"' not in project:
    print("PlayerProtocol autoload is missing.")
    sys.exit(1)

provider = (ROOT / "game/protocol/runtime_observation_provider.gd").read_text(encoding="utf-8")
if '"finding"' in provider:
    print("Scoped observation provider leaks full inspection finding.")
    sys.exit(1)

print("NC-007 player protocol validation: PASS")
