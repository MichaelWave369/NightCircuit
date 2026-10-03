from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-008 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "protocol/transports/local_agent_server.gd",
    [
        'BIND_ADDRESS := "127.0.0.1"',
        "PORT := 36970",
        'SOURCE_ID := "agent"',
        'SEAT_ACTOR := "phi_bot"',
        "MAX_CLIENTS := 1",
        "MAX_LINE_CHARS := 65536",
        "MIN_ACTION_INTERVAL_MS := 50",
        "TCPServer.new()",
        "seat_actor_mismatch",
        "action_rate_limited",
        'get_node_or_null("/root/PlayerProtocol")',
        "handle_adapter_message(SOURCE_ID, message)",
        '"transport": "tcp-jsonl"',
    ],
)

server = (ROOT / "protocol/transports/local_agent_server.gd").read_text(encoding="utf-8")
for forbidden in ('BIND_ADDRESS := "0.0.0.0"', 'BIND_ADDRESS := "*"', 'SEAT_ACTOR := "hunter"'):
    if forbidden in server:
        print(f"Local agent seat violates NC-008 safety boundary: {forbidden}")
        sys.exit(1)

require_tokens(
    "tools/p3_client.py",
    [
        'HOST = "127.0.0.1"',
        "DEFAULT_PORT = 36970",
        "class P3Client",
        '"type": "describe"',
        '"type": "observe"',
        '"type": "act"',
        '"actor": "phi_bot"',
    ],
)

require_tokens(
    "tools/p3_ollama_agent.py",
    [
        'OLLAMA_URL = "http://127.0.0.1:11434/api/chat"',
        "P3Client",
        '"type": "observe"',
        '"type": "act"',
        "sanitize_choice",
        "capabilities",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "local_agent_server.gd",
        'name="LocalAgentServer"',
        "AgentSeatState",
        "NC-008 // LOCAL AGENT SEAT",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "local_agent_server.server_state_changed.connect",
        "local_agent_server.message_processed.connect",
        "_update_agent_seat_readout",
        "server_snapshot",
    ],
)

print("NC-008 local agent seat validation: PASS")
