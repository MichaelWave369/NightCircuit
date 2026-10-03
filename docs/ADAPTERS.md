# P3 Adapter Boundary

P3 is the semantic seam between Night Circuit and any external player process.

## Transport-neutral core

`PlayerProtocol.handle_adapter_message(source, message)` remains the game-facing interface.

A transport is responsible for:

1. receiving bytes or structured input;
2. assigning a trusted source class;
3. enforcing its seat boundary;
4. decoding one P3 message;
5. passing it to PlayerProtocol;
6. encoding the returned P3 response.

It is not allowed to manipulate game actors directly.

## NC-008 local transport

NC-008 implements the first external transport as newline-delimited JSON over TCP.

Frozen defaults:

- bind: `127.0.0.1`
- port: `36970`
- source: `agent`
- seat actor: `phi_bot`
- active clients: 1
- max unfinished line: 65,536 characters
- minimum action interval: 50 ms

The server deliberately binds to loopback, not the LAN.

A connected process cannot request the Hunter seat through this transport. OBSERVE and ACT are locked to `phi_bot`; attempts to name another actor return `seat_actor_mismatch`.

## Wire format

One JSON object per line.

Request:

```json
{"type":"observe","actor":"phi_bot","request_id":"req-1"}
```

Response:

```json
{"schema":"phi-player-protocol/response/0.3","type":"observation","request_id":"req-1","ok":true,"body":{...},"error":""}
```

The transport may create a request ID when the caller omits one.

## Handshake

`describe` is augmented with a transport seat record:

```json
{
  "seat": {
    "transport": "tcp-jsonl",
    "bind": "127.0.0.1",
    "port": 36970,
    "source": "agent",
    "actor": "phi_bot"
  }
}
```

This record describes transport authority. It does not replace the Authority Gate or actor capability map.

## Reference clients

`tools/p3_client.py` is a dependency-free CLI client.

`tools/p3_ollama_agent.py` is an optional local-model loop that talks to Ollama at `127.0.0.1:11434`, requests a Φ-Bot observation, asks the local model for one action, submits it through P3, and reads the effect receipt.

Neither client receives a privileged game API.

## Security boundary

Connection is not authority.

```text
local TCP client
      |
 seat lock: phi_bot
      |
      P3
      |
Action Contract
      |
Authority Gate
      |
Actor capability
      |
Effect receipt
```

The transport protects the seat. The game still governs the verb.
