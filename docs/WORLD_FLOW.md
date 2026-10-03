# NC-003 World Flow

NC-003 is the first time Night Circuit behaves like a place rather than a controller sandbox.

## Room cells

The sewer greybox is 3840×720 and divided into three 1280×720 traversal cells.

```text
┌──────────────────┬──────────────────┬──────────────────────┐
│  INTAKE SHAFT    │    SPILLWAY      │  CISTERN APPROACH    │
│                  │                  │                      │
│ run / first gap  │ wall movement    │ ledges / boss gate   │
│       ● CP1      │       ● CP2      │        ● CP3         │
└──────────────────┴──────────────────┴──────────────────────┘
```

Entering a room updates the Hunter camera limits to that cell. The player can still cross naturally at the boundary, but the camera stops showing unqualified adjacent space.

## Checkpoints

NC-003 checkpoints are **session-local**.

They record:

- checkpoint ID
- respawn position

They deliberately do not write files or pretend to be the final save system.

On a fall below the sewer kill plane, the world asks the Hunter to reset to the latest checkpoint.

## World authority

Normal movement remains actor-owned and governed by the Action Bus.

The world has limited environmental authority to:

- constrain the camera
- activate a checkpoint
- force a respawn after entering an invalid world region

That distinction matters. A checkpoint can relocate the Hunter because respawn is a world rule, while a keyboard adapter still cannot directly set position or velocity.

## Greybox purpose

These rooms are not intended as final level design.

They exist to answer:

- Does the controller survive multiple traversal shapes?
- Does camera segmentation feel readable?
- Does a fall/respawn loop work cleanly?
- Can room identity become part of observations and receipts?
- Is there enough space for NC-004 combat to be layered in next?
