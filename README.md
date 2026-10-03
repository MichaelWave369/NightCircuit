# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Current milestone: NC-008 — Local External Agent Seat

Night Circuit now exposes a real external player seat.

When the game is running, a loopback-only TCP JSONL server listens at:

```text
127.0.0.1:36970
```

That transport is permanently locked to:

```text
source = agent
actor  = phi_bot
```

So an external process can DESCRIBE, OBSERVE, and ACT through P3 without receiving Hunter control or direct access to Godot nodes.

### Manual external control

```bash
python tools/p3_client.py describe
python tools/p3_client.py observe
python tools/p3_client.py act FOLLOW
python tools/p3_client.py act INSPECT
```

### Local AI control with Ollama

With a local Ollama model installed:

```bash
python tools/p3_ollama_agent.py --model qwen3:4b --steps 30
```

The loop is real:

```text
external model
     |
     v
OBSERVE Φ-Bot
     |
     v
choose action
     |
     v
ACT through P3
     |
     v
Action Bus
     |
Authority Gate
     |
Φ-Bot executor
     |
effect receipt
     |
     +---- back to model
```

The external model does not get a cheat pipe. Humanity has tried that architecture often enough.

## Seat safety

NC-008 freezes several development constraints:

- loopback only
- one connected client
- Φ-Bot actor lock
- bounded message size
- bounded ACT rate
- existing typed action validation
- existing Authority Gate
- existing capability checks
- existing decision/effect receipts

## In-game controls

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
| O | in-game P3 Φ-Bot observation |

## Next rung

**NC-009 — Ash Village:** the first hub with NPC schedules, testimony, routes, and the foundation for the coming day/night state change.

## License

MIT. See [LICENSE](LICENSE).
