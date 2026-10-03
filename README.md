# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

Night Circuit combines deliberate 2D exploration, towns that change with the night cycle, hidden routes, evidence-driven mysteries, and a physical AI companion called **Φ-Bot**.

The defining rule is simple:

> An agent is never merely dialogue. If it inhabits the world, it can act upon the world.

## Current milestone: NC-003 — Sewer Test Room

NC-003 replaces the one-screen movement lab with the first traversable world slice: a three-room sewer greybox with camera bounds, checkpoints, hazards, and room flow.

The Hunter now moves through:

1. **INTAKE SHAFT** — basic run/jump gap
2. **SPILLWAY** — wall-kick and vertical traversal
3. **CISTERN APPROACH** — ledges leading toward the future Fallen arena

Checkpoints are session-local on purpose. Save persistence belongs later.

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

## Architecture

Human input still does not write directly to Hunter velocity.

```text
Input adapter
    ↓
Action Bus
    ↓
Authority Gate
    ↓
Hunter
    ↓
World traversal
```

The world may respawn or constrain the Hunter, but it does not bypass the action contract for ordinary player movement.

## Roadmap

NC-004 is combat: light attack, heavy attack, dodge, damage, health, and a simple enemy family.

## License

MIT. See [LICENSE](LICENSE).
