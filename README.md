# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Current milestone: NC-010 — Day / Night

Ash Village now changes when the bell rings.

Approach the Bell Road bell and press **R**.

```text
DUSK
  |
 BELL
  v
NIGHT
  |
 BELL
  v
 DAY
  |
 BELL
  v
NIGHT ...
```

This is not merely a lighting toggle.

At Night:

- NPC schedules change
- some NPCs disappear indoors while others emerge
- testimony can change
- Mara's shop closes
- Drain Husks enter the village
- Bell Road geometry changes
- an elevated route appears while the direct path is obstructed
- Φ-Bot detects stronger temporal resonance and a route discontinuity
- reality consistency falls from the dusk baseline

Prototype consistency values:

```text
DAY   96%
DUSK  92%
NIGHT 81%
```

P3 observations expose the current phase and world-state diagnostics without bypassing scoped perception.

## External Φ-Bot seat

The local P3 seat remains available at:

`127.0.0.1:36970`

An external model can therefore experience the same day/night transition through observations and legal Φ-Bot actions.

## Controls

| Input | Action |
|---|---|
| A / D or arrows | Move |
| Space / W / Up | Jump / wall kick |
| S / Down | Crouch / ledge drop |
| J / Z | Light attack |
| K / X | Heavy attack |
| C / L | Dodge |
| R | Talk / interact / ring Bell Road bell |
| F | Φ-Bot Follow |
| H | Φ-Bot Hold |
| Q | Φ-Bot Light |
| E | Φ-Bot Inspect |
| P | Φ-Bot PING test |
| O | P3 Φ-Bot observation |

## Next rung

**NC-011 — Reality Ledger:** persist claims, observations, evidence, provenance, confidence, and contradictions so noticing the wrongness becomes actual progression.

## License

MIT. See [LICENSE](LICENSE).
