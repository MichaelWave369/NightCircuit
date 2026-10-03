# NC-011 Reality Ledger

The Reality Ledger is the game's knowledge system.

It is deliberately separate from the command Receipt Ledger.

The Receipt Ledger answers:

> What action was proposed, authorized, and executed?

The Reality Ledger answers:

> What has the player party learned about the world, where did it come from, and what disagrees with what?

## Record types

The ledger accepts six types:

- `claim`
- `observation`
- `evidence`
- `inference`
- `contradiction`
- `verified`

NC-011 actively produces claims, observations, evidence, and derived contradictions. Inference and verification are part of the contract for later progression.

## Provenance

Every record carries provenance such as:

- source kind
- source ID
- speaker / actor
- room
- world phase

This lets two statements with identical text remain distinct if they came from different sources.

## Claims

Talking to an NPC writes a structured claim.

Example:

```json
{
  "type": "claim",
  "subject": "east_bridge",
  "value": "destroyed",
  "confidence": 0.92,
  "provenance": {
    "source_kind": "npc_testimony",
    "source_id": "orin_gatekeeper",
    "phase": "DUSK"
  }
}
```

Repeatedly hearing the same phase-specific claim does not create endless duplicate rows. It increments `repeat_count`.

## Contradictions

When two claims have the same non-empty subject and different values, the ledger derives a contradiction record.

The first intended pair is:

```text
Orin:
east_bridge = destroyed

Tamsin:
east_bridge = present
```

After both are heard, the ledger creates:

```text
type: contradiction
subject: east_bridge
method: same_subject_different_value
sources: orin_gatekeeper + tamsin_cartographer
```

The ledger does not decide which source is correct.

That distinction matters. A contradiction is evidence of disagreement, not a truth oracle wearing a trench coat.

## Evidence

Successful Φ-Bot INSPECT results become evidence records with the finding, category, position, phase, and confidence.

Passive Φ-Bot anomaly signals are still not automatically promoted to evidence. The player or agent must spend the governed INSPECT action.

## Observations

Bell phase changes become direct observations with before/after phase, reality consistency, geometry revision, and current world-state snapshot.

## Persistence

Reality Ledger state is saved automatically to:

`user://night_circuit_reality_ledger_v1.json`

The schema is:

`night-circuit/reality-ledger/0.1`

Records survive a game restart.

A `clear_all()` method exists for development/reset tooling but is not bound to a casual gameplay key.

## P3

P3 observation metadata receives only a compact shared-knowledge summary:

- total records
- claim count
- observation count
- evidence count
- contradiction count
- subject count
- latest type/subject

The full ledger text is not dumped into every observation.

## NC-012 handoff

The Fallen can now use information-state progression rather than merely HP gates.

The boss rung can query whether the party has found particular contradictions/evidence, while the Reality Ledger retains provenance instead of flattening knowledge into boolean quest flags.
