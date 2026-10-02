# Hunter Movement Contract — NC-002

NC-002 establishes the first playable movement grammar.

## Intent boundary

The Hunter does **not** read keyboard state.

`NightCircuitHumanInputAdapter` reads local input and submits intent through the Action Bus:

```text
keyboard
   |
HumanInputAdapter
   |
   +-- MOVE { x }
   +-- JUMP { pressed }
   +-- CROUCH { pressed }
   |
ActionBus -> AuthorityGate -> Hunter
```

The adapter only submits when intent changes. Holding right for two seconds is one accepted MOVE intent, not 120 duplicate proposals.

This distinction matters when an AI or network adapter occupies the same seat later.

## Locomotion states

- `IDLE`
- `RUN`
- `AIR`
- `CROUCH`
- `WALL_SLIDE`
- `LEDGE_HANG`

These states describe physical outcomes. They are not privileged input commands.

For example, a governed `JUMP` intent may resolve as:

- ground jump
- coyote-time jump
- wall kick
- ledge jump

depending on world state.

## Movement feel

The starting numbers are tuning values, not lore:

- run speed: 280 px/s
- jump speed: 610 px/s
- gravity: 1850 px/s²
- coyote time: 100 ms
- jump buffer: 120 ms
- wall slide cap: 155 px/s
- wall kick: 390 px/s horizontal, 560 px/s vertical

The design target is deliberate Castlevania-weight movement with enough modern forgiveness that missed inputs feel like player mistakes rather than scheduler arguments.

## Ledge grab

A ledge is recognized when:

1. the Hunter is airborne;
2. the torso ray sees a wall;
3. the head ray sees open space;
4. the player is pressing toward that wall;
5. the re-grab lockout has expired.

While hanging:

- jump kicks away from the wall;
- crouch/down drops;
- moving away releases;
- losing wall contact releases.

NC-003 may add mantling after the sewer greybox proves it is desirable.

## Crouch

Crouching reduces the capsule height while preserving foot position.

Standing is refused when the overhead clearance sensor is blocked.

## Governance note

Action receipts in NC-002 prove **authorization of intent**, not successful movement.

Actor effect receipts are deliberately deferred to NC-006, where execution and replay semantics are hardened.
