# Roadmap

## Progress

- **NC-001 through NC-015 — COMPLETE:** Vertical Slice 0.1 assembled and runtime-qualified
- **NC-016 — COMPLETE IN THIS CHANGE:** structured playtest recorder, session summarizer, runtime integration smoke

## Vertical Slice 0.1

The qualified progression spine remains:

```text
Drain → Ash Village → Night → Reality contradiction → The Fallen
      → Scout Core → Intake backtrack → Service Vein → Altermath teaser
```

## Hardening phase

NC-016 deliberately adds no new world region.

The next work should come from playtest evidence captured by the recorder:

- traversal friction
- combat readability
- save/load defects
- controller feel
- agent-seat behavior
- UI noise
- progression ambiguity
- performance
- packaging

NC-017 should fix the highest-value evidence from real play, not reward our species' instinct to add another subsystem whenever one becomes stable.

## NC-017 — Local first-boot regression

The first Windows/Godot 4.3 hands-on launch exposed five parser errors in the Vertical Slice qualification readout. Dynamic RealityLedger calls were being assigned with inferred `:=` declarations even though the call target is only known as a generic Node at parse time.

NC-017 explicitly converts those dynamic results to `bool` and makes the runtime integration smoke preload `game/main/main.gd`, so this exact parser failure becomes CI-visible.

This rung exists because the first actual player did something revolutionary: ran the game.


## NC-018 — PixelForge Runtime Bridge

Night Circuit implements the same Runtime Bridge v1 surface as Oak while
preserving Godot engine-clock semantics and native PlayerProtocol governance.

## NC-019 — External PixelForge model seat

The existing loopback P3 agent seat becomes the first real external consumer of
PixelForge AsyncRuntimeHostV1.

Acceptance requires the canonical PixelForge Ollama provider/model policy/async
host stack to cross TCP into a real headless Godot process, act only as Φ-Bot,
receive native decision/effect receipts, and observe the resulting actor state.

This rung adds no second transport and no Hunter authority.
