# PixelForge Runtime Bridge v1

NC-018 makes Φ: Night Circuit the second full game to implement the same
game-agnostic PixelForge Runtime Bridge v1 used by Oak Street Rumble.

The public surface is unchanged:

- describe()
- registerController()
- observe()
- submit()
- advance()
- events()
- snapshot()
- recording()
- authority()
- hash()

Night Circuit keeps its own internal architecture:

```text
PixelForge Runtime Bridge v1
            |
            v
       PlayerProtocol
            |
            v
         ActionBus
            |
            v
       AuthorityGate
            |
            v
      Actor executors
            |
            v
       ReceiptLedger
```

## Engine-clock distinction

Oak Street Rumble is externally stepped and deterministic.

Night Circuit is a live Godot runtime. Physics advancement remains owned by the
Godot engine, so this adapter declares:

```text
deterministic = false
clockMode = "engine"
advanceSemantics = "flush-controller-batch"
replayExact = false
```

`advance()` therefore flushes one queued controller batch through the
authoritative protocol at the current bridge step. It does not impersonate or
manually advance a Godot physics frame.

## Controller-seat authority

Night Circuit's native AuthorityGate is source-class based:

```text
human | gamepad | agent | network | replay | script | system
```

The PixelForge adapter adds a thin controller-identity seat layer above it.

Registration grants observation only.

A built-in human seat owns the initial Hunter action surface and may delegate a
subset of those actions with the Night Circuit-specific bridge intent:

```text
actor = "bridge"
action = "DELEGATE_CONTROLLER"
payload = {
  controller_id,
  actor,
  actions
}
```

Only delegated actions reach PlayerProtocol. The native AuthorityGate still
performs its own source/actor/action validation afterward.

That preserves both invariants:

```text
connected != authorized
bridge grant != bypass of native authority
```

## Qualification

The executable Godot smoke proves:

1. a script controller can register and observe Hunter,
2. registration grants zero action authority,
3. an unauthorized MOVE is rejected by the bridge seat,
4. human authority delegates MOVE + LIGHT_ATTACK,
5. the delegated MOVE reaches the real PlayerProtocol and ActionBus,
6. the native ReceiptLedger records an accepted script/Hunter/MOVE decision,
7. snapshots, recordings, authority views and hashes are exported through the
   PixelForge surface,
8. the adapter does not claim exact deterministic replay for the engine-clocked
   runtime.

Oak and Night Circuit therefore implement the same external bridge while keeping
different engines, clocks, action grammars and authority internals.
