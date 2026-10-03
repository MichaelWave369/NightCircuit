# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Vertical Slice 0.1 + NC-018 PixelForge Runtime Bridge

The first complete slice remains:

```text
Drain → Ash Village → Night → The Fallen → Scout → Backtrack
      → Service Vein → Altermath teaser
```

NC-016 added the playtest harness. NC-017 hardened first local boot. NC-018 now makes Night Circuit the second full game to implement PixelForge Runtime Bridge v1 without replacing its native Godot protocols.

### Playtest capture

Debug builds record structured NDJSON events under:

`user://playtests/`

Useful keys:

- **F8** manual playtest marker
- **F7** export session summary
- **F5** save
- **F9** load

A small offline summarizer is included:

```bash
python tools/summarize_playtest.py <playtest-log.ndjson>
```

### Runtime CI

The Godot 4.3 job now runs three levels:

1. headless parse/import
2. project boot smoke
3. executable integration smoke

The integration smoke performs an actual RunSave roundtrip and proves the Reality Ledger derives a contradiction from two conflicting claims.

That is more useful evidence than discovering that a Python token checker remains extremely talented at finding strings.

## Status

**Vertical Slice 0.1 hardening + cross-engine runtime bridge qualification**

The next changes should come from hands-on playtest evidence rather than immediate map expansion.

## License

MIT. See [LICENSE](LICENSE).

### NC-017 local first-boot fix

The first Windows Godot 4.3 editor launch found a parser regression in the five Vertical Slice qualification booleans.

The fix uses explicit boolean conversion for dynamic RealityLedger calls and forces `main.gd` through the executable integration-smoke preload path.

If you pulled the repository before NC-017, update `main` before the first local run.


### NC-018 PixelForge Runtime Bridge

Night Circuit now exposes the same ten-method PixelForge Runtime Bridge v1
surface as Oak Street Rumble. The adapter preserves Night Circuit's native
PlayerProtocol, ActionBus, AuthorityGate and ReceiptLedger.

Because Night Circuit is engine-clocked, the descriptor explicitly reports
`deterministic: false`, `clockMode: "engine"`, and non-exact replay rather
than pretending a bridge batch is a Godot physics frame.

See `docs/PIXELFORGE_RUNTIME_BRIDGE.md`.
