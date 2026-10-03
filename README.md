# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Current milestone: NC-009 — Ash Village

The Drain now opens into the first real hub: **Ash Village at dusk**.

The village has three districts, moving NPC schedules, governed conversation, conflicting testimony, and a locked road toward the Bell Tower.

```text
THE DRAIN
   |
village lift
   |
ASH GATE
   |
MARKET SQUARE
   |
BELL ROAD
   |
BELL TOWER [LOCKED]
```

### Talk to people

Press **R** near a villager.

Conversation is routed through Hunter `INTERACT` on the Action Bus rather than calling an NPC directly.

Current residents already disagree about reality:

- Orin says the east bridge collapsed twenty years ago.
- Tamsin says she crossed it this morning.
- Mara warns that the three bells must not agree.
- Nell remembers a door under the clock that adults deny.

These are structured testimony records, ready for the Reality Ledger on NC-011.

### Schedules

Ash Village is frozen at **DUSK** for NC-009.

NPCs rotate through deterministic dusk schedule slots every 18 seconds, changing their location and activity. NC-010 will switch the schedule substrate between actual day/night world states.

### P3

The external Φ-Bot seat remains live at:

`127.0.0.1:36970`

P3 observations in the village can now include nearby NPCs and, near Bell Road, a passive bell-tower resonance signal.

## Controls

| Input | Action |
|---|---|
| A / D or arrows | Move |
| Space / W / Up | Jump / wall kick |
| S / Down | Crouch / ledge drop |
| J / Z | Light attack |
| K / X | Heavy attack |
| C / L | Dodge |
| R | Talk / interact |
| F | Φ-Bot Follow |
| H | Φ-Bot Hold |
| Q | Φ-Bot Light |
| E | Φ-Bot Inspect |
| P | Φ-Bot PING test |
| O | P3 Φ-Bot observation |

## Next rung

**NC-010 — Day / Night:** the bell changes NPC schedules, routes, hostiles, geometry, and reality consistency.

## License

MIT. See [LICENSE](LICENSE).
