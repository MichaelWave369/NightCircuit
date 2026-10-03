# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

Night Circuit now has a formal player-facing protocol: **P3, the Φ Player Protocol**.

## Current milestone: NC-007 — Φ Player Protocol

P3 exposes three transport-neutral message types:

```text
DESCRIBE
OBSERVE
ACT
```

The important part is what it does **not** expose: scene-tree god mode.

An agent observes through an actor-scoped provider and acts through the same Action Bus, Authority Gate, actor execution, and effect receipt path already used by the game.

### Observation flow

```text
PLAYER / AGENT
      |
      v
      P3
      |
      v
SCOPED OBSERVATION
  |           |
Hunter     Φ-Bot
view       view
```

Φ-Bot can receive anomaly signals that the Hunter observation does not. Those signals still do not reveal the full inspection finding; INSPECT remains an action with an energy cost.

### Runtime smoke test

Press **O** in the prototype to request a real P3 observation for Φ-Bot through source `agent`.

The HUD reports the observation ID, room, visible entity count, signal count, and scope.

## Existing controls

| Input | Action |
|---|---|
| A / D or arrows | Move |
| Space / W / Up | Jump / wall kick |
| S / Down | Crouch / ledge drop |
| J / Z | Light attack |
| K / X | Heavy attack |
| C / L | Dodge |
| F | Φ-Bot Follow |
| H | Φ-Bot Hold |
| Q | Φ-Bot Light |
| E | Φ-Bot Inspect |
| P | Φ-Bot PING test |
| O | P3 Φ-Bot observation |

## Next rung

**NC-008 — Agent Seat:** attach a local external process to P3 so an actual AI can request observations and control Φ-Bot through the governed path.

## License

MIT. See [LICENSE](LICENSE).
