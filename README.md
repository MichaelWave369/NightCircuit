# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

Night Circuit combines deliberate 2D exploration, towns that change with the night cycle, hidden routes, evidence-driven mysteries, and a physical AI companion called **Φ-Bot**.

The defining rule is simple:

> An agent is never merely dialogue. If it inhabits the world, it can act upon the world.

## NC-001 status

This branch establishes the Godot 4 project skeleton and the first governed action path:

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

The boot scene is deliberately tiny. Press **P** while it is running to submit a governed `PING` action for Φ-Bot and watch the receipt return through the same path future agent actions will use.

## Quick start

1. Install Godot 4.x.
2. Clone this repository.
3. Import `project.godot`.
4. Run the project.
5. Press **P** to exercise the NC-001 action/authority/receipt smoke path.

No external model or network service is required for NC-001.

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
