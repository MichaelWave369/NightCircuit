# Φ Player Protocol

Version: **0.2 draft**

The protocol exists so human, local AI, remote AI, replay, network, and scripted inputs can share one gameplay contract.

## Principle

An input source proposes an action. The game validates it, decides authority, dispatches it to the registered actor, and records what the actor reports.

No external agent receives direct authority over scene nodes.

## Action envelope

```json
{
  "schema": "night-circuit/action/0.2",
  "action_id": "act-00000042",
  "source": "agent",
  "actor": "phi_bot",
  "action": "INSPECT",
  "payload": {},
  "request_id": "optional-idempotency-key",
  "replay_of": ""
}
```

The Action Bus owns the session sequence and generates `action_id` when omitted.

## Typed payload checks

NC-006 performs structural checks before authority evaluation.

Examples:

- Hunter MOVE requires numeric `x`.
- Hunter JUMP/CROUCH require Boolean `pressed`.
- Φ-Bot MOVE requires numeric `x` and `y`.
- Φ-Bot LIGHT validates Boolean `enabled` / `toggle` when present.
- every payload must be a dictionary.

This is intentionally small. NC-007 expands the public protocol surface.

## Decision receipt

```json
{
  "receipt_type": "decision",
  "action_id": "act-00000042",
  "sequence": 42,
  "accepted": true,
  "reason": "authorized",
  "source": "agent",
  "actor": "phi_bot",
  "action": "INSPECT",
  "payload": {}
}
```

A decision receipt proves the proposal was evaluated.

It does not prove the requested effect happened.

## Effect receipt

```json
{
  "receipt_type": "effect",
  "action_id": "act-00000042",
  "sequence": 42,
  "status": "applied",
  "reason": "inspection_completed",
  "effect": {
    "inspection": {
      "status": "observed"
    }
  }
}
```

Decision and effect receipts share the same `action_id`.

Effect status is one of:

- `applied`
- `noop`
- `refused`
- `failed`

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

Observations remain deliberately scoped. An agent should receive only information that its actor is allowed to sense.

## Replay-oriented record

The Receipt Ledger can derive accepted actions into a replay tape.

Replay submits through the same Action Bus with source `replay`; it does not bypass validation or authority.

NC-006 establishes replay semantics, not deterministic replay qualification.
