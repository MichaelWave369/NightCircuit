# NC-009 Ash Village

Ash Village is the first social hub in Night Circuit.

NC-009 deliberately stops at **DUSK**. NC-010 owns the actual day/night transition.

## First hub loop

The player exits the Drain through the village lift and enters three districts:

```text
ASH GATE
   |
MARKET SQUARE
   |
BELL ROAD
   |
BELL TOWER [LOCKED]
```

The left edge returns to the Drain.

## Governed interaction

Press **R** near an NPC.

The key does not call the NPC directly.

```text
R
|
HumanInputAdapter
|
Hunter.INTERACT
|
Action Bus
|
Authority Gate
|
Hunter interaction_requested
|
active world chooses nearest NPC
|
testimony record
```

This keeps interaction on the same governed command surface used by future player agents.

## Dusk schedules

Each villager has three dusk schedule slots.

Every 18 seconds the active slot changes and the NPC walks to the next assigned location/activity.

This proves schedule machinery without stealing NC-010's job. The phase is frozen to `DUSK` in this rung.

## Testimony seeds

Four residents establish the first contradiction material:

- **Orin, Gatekeeper:** says the east bridge collapsed twenty years ago.
- **Tamsin, Cartographer:** says she crossed the east bridge at sunrise.
- **Mara, Apothecary:** says the three bells are not supposed to agree.
- **Nell, Clockmaker's child:** remembers a door under the clock that adults deny.

Each interaction returns a structured claim ID, subject, value, confidence, speaker, activity, and phase.

NC-011 will turn these records into persistent Reality Ledger evidence. NC-009 only establishes the testimony source.

## P3 visibility

Village NPCs become scoped visible entities through the existing P3 observation provider.

Near Bell Road, Φ-Bot can also receive a passive `bell_tower_resonance` signal. It is a signal, not a solved mystery.

## NC-010 handoff

NC-010 should add the actual world-state transition:

- DAY / NIGHT phase switching
- schedule selection by phase
- NPC presence/route changes
- shop closure
- hostile emergence
- route/geometry changes
- reality consistency change

The schedule substrate already exists so that work can change state rather than invent a second NPC system.
