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

## NC-002: movement intent

The Hunter controller preserves the architecture instead of bypassing it for convenience.

```text
Keyboard
   |
HumanInputAdapter
   |
   +-- MOVE
   +-- JUMP
   +-- CROUCH
   |
ActionBus
   |
AuthorityGate
   |
Hunter locomotion physics
```

The HumanInputAdapter has no Hunter reference and never writes velocity. It submits only intent changes.

The Hunter subscribes to **accepted** actions and translates those into local physics state.

This gives future adapters a stable seam:

```text
Local keyboard -----\
Gamepad -------------\
AI agent --------------> same governed Hunter intent
Network peer ---------/
Replay ---------------/
```

Derived physical events such as wall slide, ledge grab, or wall kick remain actor outcomes in NC-002. A JUMP proposal does not get to declare that a wall kick occurred; the world geometry decides that.

## Receipt semantics

NC-002 continues the NC-001 rule:

> An action receipt proves that the proposal was evaluated and authorized. It does not yet prove the intended world effect occurred.

Effect receipts arrive in NC-006 alongside replay hardening.

## Non-goals for NC-002

- no LLM SDK dependency
- no network listener
- no autonomous game loop
- no combat implementation
- no save persistence
- no effect receipt stream
- no final animation or art

The movement seam comes before the animation attached to it.
