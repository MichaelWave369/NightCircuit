# NC-013 Scout Core

NC-013 converts The Fallen's reward from a prop into Φ-Bot's first real progression form.

## Claiming the core

After defeating The Fallen, approach the Scout Core and press **R**.

The core reports approximately 0.97 compatibility and installs into Φ-Bot.

The resulting form is:

`SCOUT`

The installation is persisted as a Reality Ledger `verified` record:

```text
subject: phi_bot_form
value: SCOUT
type: verified
```

On later starts, Φ-Bot restores Scout form from that verified record.

## Ability surface

Scout unlocks four related abilities.

### Resonance Ping

Action: `PING`

Human key: **P**

Energy cost: 12

Ping gathers bounded nearby protocol signals from the active world and inspectable traces. It returns categories, confidence, range, and relative position without automatically promoting a signal to evidence.

### Anchor Mark

Action: `MARK`

Human key: **G**

Energy cost: 8

MARK operates on the most recent Ping result. With no target payload it selects the nearest ping signal. An agent may supply:

```json
{"action":"MARK","payload":{"target":"night_route_discontinuity"}}
```

The selected mark is visible from Φ-Bot as a local guidance line/ring.

### Enemy Read

Action: `SCAN`

Human key: **T**

Default mode:

```json
{"mode":"enemy_read"}
```

Energy cost: 10

Enemy Read selects the nearest visible hostile in range and returns a bounded combat classification including state, attack, phase, health ratio, and confidence where available.

### Contradiction Sense

Contradiction Sense is passive in Φ-Bot's state snapshot and may also be explicitly queried through:

```json
{"action":"SCAN","payload":{"mode":"contradiction"}}
```

The Reality Ledger provides only compact contradiction records: subject, confidence, values, and sources.

Scout does not decide which conflicting claim is true.

## Dynamic P3 capabilities

Before Scout installation:

```text
PING  unavailable
SCAN  unavailable
MARK  unavailable
```

After installation, those actions become available when energy/state requirements are satisfied.

No external-agent transport changes are needed. Existing P3 clients discover the new surface through the same dynamic capability map.

## World binding

Φ-Bot now receives the active world reference when the game changes world cells.

That lets Resonance Ping use each world's scoped `protocol_signals` implementation rather than inventing a second global sensing system.

## Persistence and boss reward restore

The Fallen arena consults the Reality Ledger for:

- direct evidence that The Fallen was defeated;
- verified evidence that Φ-Bot is already SCOUT.

This prevents the reward from reappearing as unclaimed after the form has already been verified.

## NC-014 handoff

NC-014 can now put Scout abilities to work on old terrain:

- Ping a previously silent wall
- Mark an anchor
- reveal a hidden sewer route
- use Contradiction Sense to connect information to traversal

That is where backtracking becomes information-driven progression instead of a colored keycard wearing a fake moustache.
