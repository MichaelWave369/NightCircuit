# Architecture

## Core flow

```text
+---------+  +---------+  +-------+  +---------+  +--------+  +--------+
| Human   |  | Gamepad |  | Agent |  | Network |  | Replay |  | Script |
+----+----+  +----+----+  +---+---+  +----+----+  +---+----+  +---+----+
     \            |           |           |           |           /
      \___________|___________|___________|___________|__________/
                              |
                              v
                        +-----------+
                        | ActionBus |
                        +-----+-----+
                              |
                              v
                      +---------------+
                      | AuthorityGate |
                      +-------+-------+
                              |
                    accepted  |  rejected
                              |
                              v
                         World Actor
                              |
                              v
                          Receipt(s)
```

## Boundaries

### Input adapters

Adapters translate device, network, replay, script, or model-specific output into the shared action envelope.

### Action Bus

The Action Bus normalizes and sequences proposals. It does not decide policy.

### Authority Gate

The gate checks whether the source, actor, and action are allowed. Later rungs add room state, cooldown, energy, ownership, handoff, and session grants.

### Actor

Actors own game-specific execution. The Hunter and Φ-Bot are the first actor classes.

### Receipts

Receipts make decisions inspectable and replayable. NC-001 stores them in memory only.

### Reality Ledger

The Reality Ledger is distinct from action receipts. It stores claims, observations, provenance, confidence, and contradictions that matter to exploration.

## Non-goals for NC-001

- no LLM SDK dependency
- no network listener
- no provider credentials
- no autonomous game loop
- no combat implementation
- no persistence layer

That restraint is intentional. The seam comes before the machinery attached to it.
