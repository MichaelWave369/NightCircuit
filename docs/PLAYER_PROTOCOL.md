# Φ Player Protocol

Version: **0.1 draft**

The protocol exists so human, local AI, remote AI, replay, network, and scripted inputs can share one gameplay contract.

## Principle

An input source proposes an action. The game decides whether that action is authorized and valid.

No external agent receives direct authority over scene nodes.

## Action envelope

```json
{
  "source": "agent",
  "actor": "phi_bot",
  "action": "PING",
  "payload": {
    "target": "wall_17"
  }
}
```

Required semantic fields:

- `source`: human, gamepad, agent, network, replay, script, or system
- `actor`: registered world actor
- `action`: verb from that actor's capability surface
- `payload`: action-specific dictionary

The Action Bus adds a monotonic session sequence.

## Observation envelope

```json
{
  "schema": "phi-player-protocol/observation/0.1",
  "actor": "phi_bot",
  "room": "sewer_07",
  "visible_entities": ["hunter", "wall_17"],
  "signals": {
    "wall_17": {
      "anomaly": 0.91
    }
  },
  "state": {
    "energy": 74
  }
}
```

Observations are deliberately scoped. An agent should receive only information that its actor is allowed to sense.

## Receipt envelope

```json
{
  "sequence": 42,
  "accepted": true,
  "reason": "authorized",
  "source": "agent",
  "actor": "phi_bot",
  "action": "PING",
  "payload": {
    "target": "wall_17"
  },
  "unix_time": 1790980000
}
```

A receipt proves that the game evaluated the proposal. It does **not** by itself prove the action produced its intended world effect. Effect receipts will be added when actor execution arrives.

## NC-001 scope

NC-001 provides:

- Action Bus
- Authority Gate
- in-memory receipt ledger
- observation builder
- one interactive boot-scene smoke path

It does not connect an LLM, WebSocket, or network provider yet.
