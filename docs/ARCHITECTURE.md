# Architecture

## Core flow

```text
Human / Gamepad / Agent / Network / Replay / Script
                       |
                       v
                 Action Contract
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

## Input adapters

Adapters translate device, network, replay, script, or model-specific output into the shared action envelope.

They do not hold privileged references to actors.

## Action Contract

NC-006 introduces a typed structural boundary before authority.

It owns:

- action schema
- generated action IDs
- payload validation
- effect status validation
- receipt/replay schema identifiers

## Action Bus

The Action Bus now owns the complete command lifecycle:

1. normalize
2. validate
3. deduplicate optional request IDs
4. ask Authority Gate
5. record decision
6. dispatch to a registered actor executor
7. validate actor result
8. record effect

The bus remains source-agnostic.

## Authority Gate

Authority still answers whether a source is allowed to propose a verb for an actor.

Capability and runtime state remain actor concerns.

That allows a useful distinction:

```text
PING is an authorized Φ-Bot verb
but
BROKEN form cannot execute PING yet
```

Decision: accepted.

Effect: refused.

## Actor execution

Hunter and Φ-Bot register `execute_action(action)` with the Action Bus.

Actors return:

```text
status + reason + effect
```

instead of silently consuming a global accepted-action signal.

The accepted/rejected signals remain available for observers, telemetry, and future tools, but they are no longer the execution transport.

## Receipts

The Receipt Ledger stores separate decision and effect receipts.

Decision receipts answer what governance decided.

Effect receipts answer what immediate actor execution reported.

Reality evidence remains a separate domain.

## Replay

Accepted decision receipts can be projected into a replay tape and resubmitted through the same governed path.

NC-006 does not yet promise frame-exact deterministic replay. It establishes the input provenance needed to test that claim later.
