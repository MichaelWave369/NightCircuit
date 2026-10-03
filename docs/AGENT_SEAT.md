# NC-008 Local External Agent Seat

NC-008 is the first rung where a process outside Godot can play an embodied Night Circuit actor.

The seat is intentionally narrow:

- external source: `agent`
- embodied actor: `phi_bot`
- transport: loopback TCP JSONL
- no Hunter authority
- no scene-tree access
- no direct state mutation

## Start it

Run Night Circuit normally.

The HUD should show something equivalent to:

```text
AGENT SEAT: LISTENING // 127.0.0.1:36970 // actor=phi_bot
```

If the port is already occupied, the HUD reports the listener error rather than silently moving to another port.

## Manual qualification

From the repository:

```bash
python tools/p3_client.py describe
python tools/p3_client.py observe
python tools/p3_client.py act FOLLOW
python tools/p3_client.py act HOLD
python tools/p3_client.py act INSPECT
python tools/p3_client.py act LIGHT --payload '{"toggle": true}'
```

Expected properties:

1. DESCRIBE identifies the locked Φ-Bot seat.
2. OBSERVE returns an actor-scoped Φ-Bot observation.
3. ACT returns the same decision/effect receipts used internally.
4. requesting `actor: hunter` over the raw transport is refused with `seat_actor_mismatch`.
5. Broken Form PING remains authority-accepted but capability-refused.
6. rapid ACT flooding is rate-limited before P3 dispatch.

## Optional Ollama player

With Ollama running locally:

```bash
python tools/p3_ollama_agent.py --model qwen3:4b --steps 30
```

The model loop is deliberately simple:

```text
DESCRIBE once
    |
OBSERVE phi_bot
    |
local model chooses one available action
    |
ACT phi_bot
    |
read effect receipt
    |
repeat
```

The Python process does not control the Hunter and cannot bypass P3.

Use another installed Ollama model by changing `--model`.

## Transport limits

NC-008 is a development transport, not an internet service.

It is:

- loopback-only;
- single-client;
- line-size bounded;
- action-rate bounded;
- seat-locked.

Remote networking, authentication, multi-seat arbitration, and production sandboxing are outside this rung.

## Exit condition

NC-008 passes when a process outside Godot can:

1. connect on loopback;
2. DESCRIBE P3;
3. OBSERVE Φ-Bot;
4. ACT as Φ-Bot;
5. receive correlated effects;
6. fail to cross into the Hunter seat.
