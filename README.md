# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Current milestone: NC-012 — The Fallen

The first full boss encounter is now wired into Cistern Approach.

At the red cistern seal, press **R** to enter.

### Phase 1

The Fallen uses readable physical attacks:

```text
WHIP_STRIKE
GROUND_SWEEP
CROSS_THROW
BELL_LEAP
```

Their visible source and damage source agree.

### Phase 2

At 50% health, the fight changes.

```text
CAUSAL_ECHO
```

The boss visibly attacks from one place while damage manifests at a historical Hunter position.

Φ-Bot can detect:

```text
ATTACK DETECTED:
NO PHYSICAL SOURCE
```

That warning is actor-scoped through P3 rather than painted onto the floor for the human.

### Reality Ledger

The first causal anomaly is recorded as an observation with Φ-Bot provenance.

Victory is recorded as direct combat evidence.

### Vigil Cache

There is a one-use hidden full-heal cache in suspicious masonry near the arena entrance.

### After victory

The **Scout Core** appears, but remains unclaimed.

That is deliberate.

NC-013 owns the actual Φ-Bot transformation and new ability surface.

## External Φ-Bot seat

The local P3 seat remains at:

`127.0.0.1:36970`

An external agent can therefore experience boss health, phase, attack state, and Φ-Bot-only causal anomaly signals through the same governed interface.

## Next rung

**NC-013 — Scout Core:** transform Φ-Bot and unlock Resonance Ping, Anchor Mark, Enemy Read, and Contradiction Sense.

## License

MIT. See [LICENSE](LICENSE).
