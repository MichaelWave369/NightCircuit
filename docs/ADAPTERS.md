# P3 Adapter Boundary

NC-007 defines the seam that future external players attach to.

## Transport-neutral core

`PlayerProtocol.handle_adapter_message(source, message)` is the only interface a transport needs.

A transport is responsible for:

1. receiving bytes or structured input;
2. identifying its source class;
3. decoding one P3 message;
4. passing it to PlayerProtocol;
5. encoding the returned P3 response.

It is not allowed to manipulate game actors directly.

## Current in-process qualification

The NC-007 HUD uses the same boundary as a future agent transport.

Pressing **O** submits:

```json
{
  "type": "observe",
  "actor": "phi_bot"
}
```

with source `agent`.

The HUD only displays a compact summary, but the returned structure is the full scoped observation.

## Candidate NC-008 transports

The preferred first external transport is local-only and dependency-light.

Good candidates include:

- localhost WebSocket
- localhost TCP with newline-delimited JSON
- stdin/stdout JSONL sidecar

Whatever transport is selected, the game-facing API remains P3.

## Security boundary

Transport connection is not game authority.

A connected process still has to pass:

```text
P3 adapter
   |
Action Contract
   |
Authority Gate
   |
Actor capability
   |
Effect receipt
```

That separation is the point.
