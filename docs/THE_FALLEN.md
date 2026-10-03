# NC-012 The Fallen

The Fallen is Night Circuit's first complete boss encounter.

It is intentionally split into two epistemic phases, not merely two damage multipliers.

## Entering the arena

In Cistern Approach, stand near the red cistern seal and press **R**.

The transition still comes through governed Hunter INTERACT.

The arena is a separate world cell so boss reset, camera bounds, P3 scope, and encounter signals remain contained.

## Pre-boss Vigil Cache

Suspicious masonry near the entrance hides a one-use Vigil Cache.

Press **R** close to it to restore full Hunter health.

The cache is intentionally not labeled in the world.

## Phase 1

Phase 1 uses attacks whose damage source agrees with the visible action:

- WHIP_STRIKE
- GROUND_SWEEP
- CROSS_THROW
- BELL_LEAP

Each has windup, active, and recovery timing.

The boss uses the same Hitbox/Hurtbox combat boundary as the Hunter and Drain Husk.

## Phase 2

At 50% health, The Fallen enters phase 2.

Physical attacks remain in the rotation, but the boss can now use:

`CAUSAL_ECHO`

The visible boss performs a slash from its current location.

The damage hitbox is instead instantiated at the Hunter's historical position from roughly 34 physics frames earlier.

The boss event explicitly reports:

```text
physical_source: false
classification: NO_PHYSICAL_SOURCE
```

The human is not given a bright ground marker revealing the remote hitbox.

Φ-Bot receives the causal anomaly through its actor-scoped P3 signal channel.

## Φ-Bot warning

During the causal attack the game can surface:

```text
Φ-BOT WARNING
ATTACK DETECTED:
NO PHYSICAL SOURCE
```

P3 can receive a short-lived signal:

```json
{
  "object_id": "fallen_causal_attack",
  "category": "causal_anomaly",
  "classification": "NO_PHYSICAL_SOURCE",
  "physical_source": false,
  "confidence": 0.99
}
```

This preserves the intended asymmetry: Φ-Bot can sense something the Hunter cannot directly see.

## Reality Ledger

The first detected causal attack becomes a Reality Ledger observation:

```text
subject: the_fallen_attack_source
value: no_physical_source
source: phi_bot
```

Defeating The Fallen writes direct combat evidence:

```text
subject: the_fallen
value: defeated
confidence: 1.0
```

## Defeat

After victory:

- the arena reports The Fallen defeated;
- a Scout Core appears as an unclaimed compatibility signal;
- the return route opens;
- NC-013 owns actual Scout Core acquisition and Φ-Bot transformation.

The core is deliberately visible but not claimable in NC-012.

## P3

The boss is visible as an enemy/boss entity and exposes combat fields including:

- health
- max health
- boss phase
- attack state
- whether the current attack has a physical source

The causal anomaly itself remains Φ-Bot scoped.

## Reset behavior

If the Hunter is defeated, the Hunter respawns at the arena threshold and The Fallen resets to full health and phase 1.

No attrition cheese through repeated deaths. Humanity will find enough cheese without us pre-installing it.
