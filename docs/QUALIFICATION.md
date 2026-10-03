# NC-015 Vertical Slice 0.1 Qualification

NC-015 is a qualification rung, not a content-expansion rung.

The goal is to make the existing Drain slice survive a complete play path and to close the acceptance gaps that remained after NC-014.

## Qualified loop

```text
THE DRAIN
  ↓
OLD DRAINAGE NETWORK
  ↓
ASH VILLAGE
  ↓
DAY / NIGHT + TESTIMONY
  ↓
REALITY LEDGER CONTRADICTION
  ↓
THE FALLEN
  ↓
SCOUT CORE
  ↓
BACKTRACK TO INTAKE SHAFT
  ↓
PING + MARK DORMANT ANCHOR
  ↓
SERVICE VEIN
  ↓
ALTERMATH LAYER DETECTED
```

## Save / load

The run slot is separate from the Reality Ledger.

- Reality Ledger persists knowledge and progression evidence.
- RunSave persists where the current run should resume.

Keyboard:

- **F5** writes the run slot.
- **F9** loads the run slot.

The run save stores:

- active world cell
- current checkpoint ID
- Hunter position
- Hunter health
- Ash Village phase

Boss combat is intentionally not serialized frame-for-frame. Loading a save made during The Fallen returns to the arena's safe threshold and resets active combat. Persistent victory / Scout progression still comes from the Reality Ledger.

Schema:

`night-circuit/run-save/0.1`

Path:

`user://night_circuit_run_save_v1.json`

## Controller qualification

The HumanInputAdapter now installs joypad mappings in the same InputMap actions used by keyboard input.

Core Hunter mapping:

- left stick / D-pad: movement
- A: jump
- X: light attack
- Y: heavy attack
- B: dodge
- right shoulder: interact

Φ-Bot mapping:

- left shoulder: Inspect
- left stick click: Resonance Ping
- right stick click: Enemy Read
- right trigger: Anchor Mark
- left trigger: light toggle
- Back: Follow
- Start: Hold

Controller commands do not bypass governance. They still submit through ActionBus.

## Altermath teaser

Reaching Service Vein now emits the slice's explicit teaser:

```text
ALTERMATH LAYER DETECTED
CAUSE: UNKNOWN
LOCAL REALITY CONSISTENCY: 63%
```

Φ-Bot also exposes `altermath_layer_01` through scoped sensing after discovery.

The Reality Ledger records the detection as an observation, not a proof of a physical theory.

## Runtime CI

Earlier rungs used source-contract validators. NC-015 adds an actual Godot runtime qualification job.

GitHub Actions now downloads pinned **Godot 4.3 stable** and runs:

1. headless editor parse/import
2. headless project boot smoke

This catches GDScript/resource failures that Python token validators cannot.

## Qualification HUD

The HUD tracks five persistent progression gates:

1. The Fallen defeated
2. Scout verified
3. Intake anchor route opened
4. Service Vein discovered
5. Altermath layer detected

This is not a player score. It is a development qualification readout for the vertical slice.

## Deliberate limits

NC-015 does not claim final art, final combat tuning, accessibility completion, controller certification across every hardware vendor, or release-ready packaging.

It establishes **Vertical Slice 0.1**, a coherent playable proof of Night Circuit's identity.
