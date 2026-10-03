# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

## Current milestone: NC-014 — Backtracking Loop

The first Metroidvania loop now closes.

After earning the Scout Core from The Fallen, return all the way to **Intake Shaft**.

Near the old upper wall:

```text
P  Resonance Ping
   ↓
intake_anchor_01 detected
   ↓
G  Anchor Mark
   ↓
dormant geometry reconstructs
   ↓
climb the new upper platforms
   ↓
SERVICE VEIN // UNMAPPED
```

The room was always there.

Your ability to perceive and stabilize its route was not.

### Persistent route

Opening the route writes:

```text
verified
intake_anchor_01 = route_open
```

Reaching the hidden passage writes:

```text
evidence
service_vein_01 = discovered
```

Both survive restart through the Reality Ledger.

### Agent-native backtracking

External Φ-Bot agents use the same P3 actions:

```text
OBSERVE
PING
MARK intake_anchor_01
OBSERVE
```

There is no agent-only shortcut.

### The next weird thing

Inside the Service Vein, Scout can detect:

```text
keyhole_residue_01
category: causal_residue
classification: cause_unknown
confidence: 0.71
```

No explanation yet. The game is allowed to keep one secret for more than six minutes.

## Next rung

**NC-015 — Vertical Slice 0.1 qualification:** test and harden the whole Drain → Village → Night → Fallen → Scout → Backtrack loop as one playable build.

## License

MIT. See [LICENSE](LICENSE).
