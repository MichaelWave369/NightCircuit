# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Current milestone: NC-013 — Scout Core

Defeating The Fallen now leads to Φ-Bot's first actual transformation.

Approach the Scout Core and press **R**.

```text
BROKEN
   |
SCOUT CORE
compatibility ~0.97
   |
   v
SCOUT
```

Scout unlocks:

```text
P  RESONANCE PING
G  ANCHOR MARK
T  ENEMY READ

+ passive CONTRADICTION SENSE
```

External agents use the same actions through P3:

- `PING`
- `MARK`
- `SCAN {"mode":"enemy_read"}`
- `SCAN {"mode":"contradiction"}`

### No cheat pipe

Scout abilities remain governed actions.

They cost Φ-Bot energy, produce effect receipts, and expose only bounded sensing results.

A Ping is still not evidence. INSPECT remains the evidence-producing action.

### Persistent progression

Scout installation is written to the Reality Ledger as:

```text
verified
phi_bot_form = SCOUT
```

Φ-Bot restores the form from that record on later starts.

### P3

The capability map changes dynamically when Scout installs, so the existing local external agent seat learns the new actions without a model-specific bridge.

## Next rung

**NC-014 — Backtracking loop:** return to old sewer terrain, Ping what used to look inert, Mark the anchor, and open the first progression route.

## License

MIT. See [LICENSE](LICENSE).
