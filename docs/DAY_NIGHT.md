# NC-010 Day / Night

NC-010 turns Ash Village from a static dusk hub into a stateful place whose rules change when the bell rings.

## Trigger

At Bell Road, approach the bell and press **R**.

The interaction still enters through Hunter INTERACT and the governed action path.

The phase sequence is:

```text
DUSK -> NIGHT -> DAY -> NIGHT -> ...
```

Dusk is the initial transition state. After the first bell, the village alternates between Night and Day.

## Bell event

A phase change updates several systems together:

```text
BELL
 |
 +-- visual light state
 +-- NPC presence
 +-- NPC schedules
 +-- NPC testimony
 +-- shop state
 +-- hostile population
 +-- collision geometry
 +-- Φ-Bot passive signals
 +-- reality consistency
```

The game reports the transition in the HUD rather than pretending a palette swap constitutes world simulation.

## Reality consistency

Prototype values:

- DAY: 96%
- DUSK: 92%
- NIGHT: 81%

These are game-state diagnostics, not claims about physics.

P3 observations receive the active world-state snapshot in observation metadata.

## NPC phase changes

NPCs now own schedules, testimony, and presence by phase.

Examples:

- Tamsin is present by day/dusk and indoors at night.
- Nell is absent by day and appears at dusk/night.
- Mara's shop moves OPEN -> CLOSING -> CLOSED.
- Orin changes from checking arrivals to barring the gate.

## Geometry

At Night, Bell Road changes shape.

A direct route is obstructed while an elevated night route appears.

The collision state and the drawn geometry change together.

Φ-Bot can detect a nearby `night_route_discontinuity` signal while the night geometry is active.

## Hostiles

Three Drain Husks enter Ash Village only at Night.

They are instantiated when Night begins and removed when the village returns to Day.

Existing combat rules remain unchanged.

## P3

The observation metadata now includes:

```json
{
  "world_phase": "NIGHT",
  "world_state": {
    "phase": "NIGHT",
    "reality_consistency": 81,
    "schedule_slot": 1,
    "geometry_revision": 3,
    "hostiles_active": true,
    "shop_state": "CLOSED"
  }
}
```

Passive Φ-Bot resonance around Bell Road becomes stronger at Night.

## NC-011 handoff

NC-011 can now persist:

- testimony collected in different phases,
- contradictory claims,
- direct observations,
- bell/world-state transitions,
- geometry anomalies,
- provenance and confidence.

That is the point where information itself becomes progression.
