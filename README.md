# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

Night Circuit combines deliberate 2D exploration, towns that change with the night cycle, hidden routes, evidence-driven mysteries, and a physical AI companion called **Φ-Bot**.

> An agent is never merely dialogue. If it inhabits the world, it can act upon the world.

## Current milestone: NC-004 — Combat Foundation

NC-004 gives the Hunter a real combat loop while preserving the governed input path.

The prototype now includes:

- light attack
- heavy attack
- dodge with invulnerability
- health and damage
- reusable hitbox / hurtbox boundaries
- knockback and hit-stun
- first ordinary enemy: **Drain Husk**
- enemy windup / active / recovery attack phases
- combat HUD state

The HumanInputAdapter still cannot manipulate Hunter physics or health directly.

```text
Keyboard
   |
HumanInputAdapter
   |
Action Bus
   |
Authority Gate
   |
Hunter
   |
Hitbox -> Hurtbox -> Damage Receiver
```

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
| J / Z | Light attack |
| K / X | Heavy attack |
| C / L | Dodge |
| P | Governed Φ-Bot PING smoke action |

## Current route

- Intake Shaft
- Spillway
- Cistern Approach
- future Fallen gate

Drain Husks now occupy the sewer so movement and combat can be tested together instead of in separate laboratory terrariums like unfortunate software rodents.

## Next rung

**NC-005 — Φ-Bot Entity:** make Φ-Bot a real embodied actor with Follow, Hold, Light, and Inspect.

## License

MIT. See [LICENSE](LICENSE).
