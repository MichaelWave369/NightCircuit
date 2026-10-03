# NC-005 Φ-Bot Contract

NC-005 changes Φ-Bot from a reserved agent seat into an embodied world actor.

## Broken Form

The starting form is intentionally limited.

Capabilities:

- `FOLLOW`
- `HOLD`
- `LIGHT`
- `INSPECT`

The Authority Gate already exposes future verbs such as PING, SCAN, and MARK, but Broken Form does not implement those abilities as gameplay effects yet.

## Follow

Φ-Bot maintains a floating offset on the opposite side of the Hunter's facing direction.

The bot:

- accelerates toward the follow target
- softly bobs rather than snapping every frame
- teleports only when separation exceeds a large recovery threshold
- ignores physical world collision in Broken Form

The collision choice is deliberate for this rung. Companion pathfinding and small-body navigation should not become NC-005's accidental six-week side quest.

## Hold

HOLD stops autonomous following.

This matters because later puzzles, switches, scouting, and asymmetric combat will require the bot to remain separated from the Hunter.

## Light

LIGHT projects a prototype visible illumination field.

Energy behavior:

- max energy: 100
- light drain: 8 per second
- passive recharge while light is off: 5 per second
- light shuts down at zero energy

The current rendering is a debug/prototype field, not final scene lighting.

## Inspect

INSPECT searches the nearest object in the `inspectable` group within 190 pixels.

An observed object can return:

- object ID
- title
- finding
- category
- confidence
- world position

Inspect costs 10 energy.

If there is no valid target or insufficient energy, the result still reports a structured status rather than silently failing.

## Prototype inspectables

NC-005 places:

1. **Sealed maintenance aperture**
   - category: structural anomaly
   - establishes the impossible-door idea

2. **Night War emergency cache**
   - category: hidden structure
   - seeds the later Vigil Cache mechanic

These observations are not yet written into the Reality Ledger. That integration belongs to NC-011.

## Agent-native implication

The important seam is now real:

```text
human / future agent
        |
        v
    Action Bus
        |
        v
  Authority Gate
        |
        v
      Φ-Bot
   /    |     \
FOLLOW LIGHT INSPECT
```

An external agent does not need a special companion API. It will eventually submit the same governed verbs.
