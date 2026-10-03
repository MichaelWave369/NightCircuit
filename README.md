# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

Night Circuit combines deliberate 2D exploration, towns that change with the night cycle, hidden routes, evidence-driven mysteries, and a physical AI companion called **Φ-Bot**.

> An agent is never merely dialogue. If it inhabits the world, it can act upon the world.

## Current milestone: NC-005 — Φ-Bot Entity

Φ-Bot is now an embodied world actor instead of a reserved icon.

The Broken Form supports:

- **FOLLOW** — trail the Hunter with a floating offset
- **HOLD** — stop and remain at the current position
- **LIGHT** — project a visible local illumination field while consuming energy
- **INSPECT** — examine the nearest inspectable world object and return a structured result
- energy drain and recharge
- state snapshots suitable for future observations
- governed commands through the same Action Bus used by every other player seat

### Φ-Bot controls

| Input | Command |
|---|---|
| F | Follow |
| H | Hold |
| Q | Toggle Light |
| E | Inspect nearest object |
| P | Existing governed PING smoke action |

Combat and movement controls remain unchanged.

## Current route

The sewer now contains prototype inspectables, including an impossible-door trace and a Night War emergency cache marker. These are deliberately primitive evidence targets, not final art or final Reality Ledger integration.

## Architecture

```text
Human command
     |
HumanInputAdapter
     |
Action Bus
     |
Authority Gate
     |
   Φ-Bot
   / | \
move light inspect
```

The input adapter does not hold a Φ-Bot reference and cannot directly mutate its position, energy, light state, or inspection results.

## Next rung

**NC-006 — Action Bus Hardening:** typed action contracts, actor execution results, effect receipts, and replay-oriented semantics.

## License

MIT. See [LICENSE](LICENSE).
