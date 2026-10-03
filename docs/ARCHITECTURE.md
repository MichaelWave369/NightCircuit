# Architecture

## Core flow

```text
Human / Gamepad / Agent / Network / Replay / Script
                       |
                       v
                 P3 Adapter Boundary
                 /                \
            OBSERVE               ACT
               |                  |
               v                  v
       Scoped Observation    Action Contract
                                  |
                                  v
                              ActionBus
                                  |
                            decision receipt
                                  |
                                  v
                           AuthorityGate
                                  |
                             accepted?
                            /         \
                          no           yes
                          |             |
                          v             v
                   rejected receipt  actor executor
                                        |
                                        v
                                   effect receipt
```

## P3

NC-007 introduces a transport-neutral player protocol.

A transport only needs to call:

`PlayerProtocol.handle_adapter_message(source, message)`

Supported message types:

- describe
- observe
- act

This means NC-008 can add external connectivity without creating another game API.

## Observation providers

PlayerProtocol does not inspect the scene tree itself.

Game runtime code registers scoped observation providers for actors.

The current sewer provider exposes:

- nearby embodied entities
- actor state
- actor capability availability
- room/checkpoint metadata
- Φ-Bot-only anomaly signals

It does not expose an omniscient scene dump.

## Action path

P3 ACT messages enter the NC-006 Action Bus exactly like other sources.

The PlayerProtocol cannot directly call Hunter or Φ-Bot execution methods.

## Capability versus authority

Authority answers whether a source may ask an actor to perform a verb.

The actor capability map answers whether that verb is currently available.

Both are observable, and neither substitutes for the other.

## Receipts

P3 action responses include the same correlated decision/effect receipts already stored by ReceiptLedger.

No parallel receipt system is introduced.

## Replay

Replay remains a governed Action Bus source.

P3 is complementary: it is the semantic player-facing boundary, while replay is a provenance-preserving source of actions.
