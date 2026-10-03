# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Current milestone: NC-011 — Reality Ledger

Night Circuit now remembers what the party has actually learned.

The Reality Ledger is separate from the Action/Receipt Ledger:

```text
ACTION RECEIPTS
what was proposed / authorized / executed

REALITY LEDGER
what was claimed / observed / evidenced / contradicted
```

### Talk to both sides of a contradiction

In Ash Village:

```text
Orin:
east_bridge = destroyed

Tamsin:
east_bridge = present
```

Talk to both and the ledger derives a contradiction on `east_bridge`.

It records disagreement. It does **not** arbitrarily choose a winner.

### Evidence

Successful Φ-Bot INSPECT results become persistent evidence records.

Passive anomaly sensing remains only a signal until the bot actually performs INSPECT.

### World observations

Bell transitions are recorded with phase, reality consistency, geometry revision, and world-state provenance.

### Persistence

The ledger autosaves to:

`user://night_circuit_reality_ledger_v1.json`

Repeated identical testimony is deduplicated and increments a repeat counter instead of manufacturing fake novelty.

### P3

External Φ-Bot observations now receive a compact Reality Ledger summary, including contradiction count, without dumping the full knowledge database into every model turn.

## Current information loop

```text
TALK / INSPECT / WORLD EVENT
           |
           v
     REALITY LEDGER
      /     |      \
   CLAIM  EVIDENCE OBSERVATION
      \      |      /
       CONTRADICTION
            |
        PERSISTENCE
            |
       P3 SUMMARY
```

## Next rung

**NC-012 — The Fallen:** the first boss encounter, including ordinary readable attacks and the first impossible attack source.

## License

MIT. See [LICENSE](LICENSE).
