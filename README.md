# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

Night Circuit combines deliberate 2D exploration, towns that change with the night cycle, hidden routes, evidence-driven mysteries, and a physical AI companion called **Φ-Bot**.

The defining rule is simple:

> An agent is never merely dialogue. If it inhabits the world, it can act upon the world.

## Current milestone: NC-002 — Hunter Controller

NC-002 turns the skeleton into the first playable movement lab.

The Hunter now supports:

- run with acceleration and braking
- jump buffering and coyote time
- short-hop jump release
- crouch with a reduced collider
- wall slide
- wall kick
- ledge grab and controlled release
- a governed human input adapter that never writes directly to Hunter velocity

The control path remains:

```text
Human / Gamepad / Agent / Network / Replay / Script
                       |
                       v
                  ACTION BUS
                       |
                       v
                AUTHORITY GATE
                       |
                       v
                     ACTOR
                       |
                       v
                    RECEIPT
```

NC-002 is intentionally still a movement lab. **NC-003** turns it into the first sewer traversal greybox with camera, checkpoints, and room flow.

## Quick start

1. Install Godot 4.x.
2. Clone this repository.
3. Import `project.godot`.
4. Run the project.

### Controls

| Input | Action |
|---|---|
| A / Left Arrow | Move left |
| D / Right Arrow | Move right |
| Space / W / Up Arrow | Jump / wall kick |
| S / Down Arrow | Crouch / drop from ledge |
| P | Governed Φ-Bot PING smoke action |

The human input adapter registers these keyboard bindings at runtime if the actions do not already exist. That keeps the controller logic behind the same action seam that future remapping and agent adapters will use.

## Design pillars

- **Metroidvania first.** Movement, combat, map knowledge, and meaningful backtracking must stand on their own.
- **AI is a player seat.** Φ-Bot is a world actor, not a chat panel with wings.
- **Capability is not authority.** Every action source enters the same governed action path.
- **Evidence is gameplay.** The Reality Ledger stores observations and contradictions rather than ordinary quest checkboxes.
- **Incomplete viewpoints.** Human and agent players never receive identical information.
- **Altermath changes traversal.** Hidden causal structure eventually becomes a navigable layer of the world.

See `docs/` for the design contract and vertical-slice plan.

## Roadmap

NC-001 through NC-015 builds toward the first playable slice, **The Drain**, ending with The Fallen boss, Scout Core, immediate backtracking payoff, and the first Altermath anomaly.

## License

MIT. See [LICENSE](LICENSE).
