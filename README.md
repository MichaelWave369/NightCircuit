# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Vertical Slice 0.1 + NC-016 Playtest Harness

The first complete slice remains:

```text
Drain → Ash Village → Night → The Fallen → Scout → Backtrack
      → Service Vein → Altermath teaser
```

NC-016 does not add another zone. It adds the machinery to learn what breaks when a human actually plays the thing.

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

**Vertical Slice 0.1 hardening**

The next changes should come from hands-on playtest evidence rather than immediate map expansion.

## License

MIT. See [LICENSE](LICENSE).

### NC-017 local first-boot fix

The first Windows Godot 4.3 editor launch found a parser regression in the five Vertical Slice qualification booleans.

The fix uses explicit boolean conversion for dynamic RealityLedger calls and forces `main.gd` through the executable integration-smoke preload path.

If you pulled the repository before NC-017, update `main` before the first local run.
