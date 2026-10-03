# Φ Player Protocol

Version: **0.3 draft**

The Φ Player Protocol, or **P3**, is the transport-neutral contract between a player seat and Night Circuit.

It is designed so a human adapter, local model, remote model, network peer, replay system, or script can all use the same semantic surface without receiving direct access to scene nodes.

## Message boundary

Every adapter sends one of three message types:

- `describe`
- `observe`
- `act`

Message schema:

`phi-player-protocol/message/0.3`

Response schema:

`phi-player-protocol/response/0.3`

No networking library is part of NC-007. A future transport wraps this contract rather than redefining it.

## Describe

Request:

```json
{
  "type": "describe",
  "request_id": "req-1"
}
```

The response reports:

- protocol version
- schemas
- registered actors
- observable actors
- action surfaces

This gives an agent a machine-readable handshake before it attempts play.

## Observe

Request:

```json
{
  "type": "observe",
  "actor": "phi_bot",
  "request_id": "req-2"
}
```

Observation schema:

`phi-player-protocol/observation/0.3`

Example:

```json
{
  "observation_id": "obs-00000042",
  "actor": "phi_bot",
  "room": "intake_shaft",
  "visible_entities": [
    {
      "id": "Hunter",
      "kind": "hunter",
      "distance": 91.3,
      "position": [180, 570]
    }
  ],
  "signals": {
    "impossible_door_trace": {
      "object_id": "impossible_door_trace",
      "category": "structural_anomaly",
      "confidence": 0.93,
      "distance": 188.0
    }
  },
  "state": {
    "form": "BROKEN",
    "energy": 84
  },
  "capabilities": {
    "INSPECT": {"available": true},
    "PING": {
      "available": false,
      "reason": "ability_unavailable_in_broken_form"
    }
  },
  "metadata": {
    "scope": "phi_bot",
    "checkpoint": "drain_entry",
    "world_layer": "baseline"
  }
}
```

## Scoped perception

Observations are actor-scoped.

The Hunter and Φ-Bot do not receive a shared omniscient world dump.

In the NC-007 sewer provider:

- both can perceive nearby embodied entities;
- Φ-Bot receives anomaly signals from nearby inspectables;
- the signal does **not** contain the full inspection finding;
- full finding text still requires a governed INSPECT action;
- each actor receives its own internal state and capability availability.

That asymmetry is a gameplay rule, not merely a UI choice.

## Act

Request:

```json
{
  "type": "act",
  "actor": "phi_bot",
  "action": "INSPECT",
  "payload": {},
  "request_id": "req-3"
}
```

P3 forwards the action into the existing Action Bus.

The response returns the correlated decision and effect receipts.

P3 does not bypass:

- typed action validation
- Authority Gate
- actor capability/state
- effect receipt generation

## Capability surface

Authority and capability are intentionally different.

The Authority Gate can say that PING is a valid Φ-Bot verb while Broken Form reports:

```json
{
  "PING": {
    "available": false,
    "reason": "ability_unavailable_in_broken_form"
  }
}
```

An agent can therefore reason about what is legal, what is currently possible, and why those differ.

## NC-008 handoff

NC-008 should add a local external transport and player seat on top of this boundary.

It should not invent another game-control API.
