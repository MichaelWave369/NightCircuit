# NC-016 Playtest Protocol

NC-016 is the first post-slice hardening rung.

It adds evidence collection rather than more castle.

## Recorder

Debug builds automatically write structured NDJSON events to:

`user://playtests/`

Release builds leave the recorder off unless:

`NIGHT_CIRCUIT_PLAYTEST=1`

This avoids quietly turning a normal player session into a telemetry product.

## Useful keys

- **F8** adds a manual playtest marker with current world, room, and checkpoint.
- **F7** exports a compact JSON session summary.
- **F5 / F9** remain save/load.

## Recorded surfaces

The recorder captures compact events for:

- governed action effects
- Reality Ledger additions and contradictions
- save/load
- P3 observations and errors
- world transitions
- Hunter defeat
- Fallen anomaly / defeat
- Scout Core claim
- backtrack route opening
- Service Vein discovery
- Altermath teaser

The event stream is intended for debugging and playtest analysis, not gameplay authority.

## Manual qualification pass

Run one clean keyboard pass and one controller pass.

For each pass, check the complete progression spine:

1. traverse the Drain;
2. reach Ash Village;
3. talk to Orin and Tamsin and confirm a contradiction is derived;
4. ring the bell and confirm Night changes NPCs, hostiles, and geometry;
5. enter The Fallen;
6. verify at least one causal warning;
7. defeat The Fallen;
8. claim Scout;
9. return to Intake Shaft;
10. Ping and Mark `intake_anchor_01`;
11. enter Service Vein;
12. confirm the Altermath teaser;
13. save and reload at least once outside the boss;
14. save and reload once in the boss arena and confirm safe-reset behavior.

Press F8 whenever something feels wrong or unexpectedly good. Human memory is famously reliable right up until anyone asks for exact reproduction steps.

## Summarizing a session

Given an NDJSON log copied from the Godot user-data directory:

```bash
python tools/summarize_playtest.py path/to/night_circuit_pt-....ndjson
```

The tool reports event counts, duration, recent refused/failed actions, and manual markers.

## Runtime integration CI

NC-016 extends the Godot job with an executable integration script that verifies:

- RunSave write/read roundtrip;
- Reality Ledger claim insertion;
- automatic contradiction derivation with source provenance.

This is distinct from token validators and the ordinary project boot smoke.
