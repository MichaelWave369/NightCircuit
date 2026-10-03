# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Vertical Slice 0.1 — NC-015

The first complete Night Circuit progression loop is now assembled and qualification-gated:

```text
THE DRAIN
   ↓
ASH VILLAGE
   ↓
DAY / NIGHT + conflicting testimony
   ↓
THE FALLEN
   ↓
SCOUT CORE
   ↓
backtrack to INTAKE SHAFT
   ↓
PING + MARK dormant anchor
   ↓
SERVICE VEIN
   ↓
ALTERMATH LAYER DETECTED
```

### Save / load

- **F5** save current run position/state
- **F9** load the run slot

Knowledge/progression remains in the Reality Ledger. The run slot stores location, checkpoint, health, and village phase.

Boss combat resumes from a safe arena reset instead of attempting to serialize a half-finished attack frame.

### Controller support

Controller input enters the same HumanInputAdapter → ActionBus → Authority Gate path as keyboard input.

Hunter supports left stick/D-pad movement plus standard ABXY combat/traversal controls. Φ-Bot Scout commands also have controller bindings.

### Altermath teaser

After discovering Service Vein:

```text
ALTERMATH LAYER DETECTED
CAUSE: UNKNOWN
LOCAL REALITY CONSISTENCY: 63%
```

It is recorded as an in-game observation, not presented as established real-world physics.

### Runtime qualification

CI now includes pinned Godot 4.3 headless parse/import and boot-smoke jobs in addition to all NC-002 through NC-015 contract validators.

That matters because "the Python script found the right words" is a tragically low bar for declaring a game runnable.

## Status

**Vertical Slice 0.1 candidate**

The slice still needs hands-on playtest/tuning before anything resembling a public gameplay release, but its core identity is now represented end to end.

## License

MIT. See [LICENSE](LICENSE).
