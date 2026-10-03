# NC-019 — PixelForge async model seat

NC-019 qualifies the canonical PixelForge model stack against the existing
Night Circuit external agent seat.

No second Godot server is introduced.

```text
Ollama Provider v1
        |
        v
ModelPolicyClientV1
        |
        v
AsyncRuntimeHostV1
        |
        v
Night Circuit P3 Runtime Bridge Client
        |
        v
127.0.0.1:36970 / TCP JSONL
        |
        v
LocalAgentServer
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
Φ-Bot executor
```

## Why AsyncRuntimeHostV1

Oak runs in-process with PixelForge, so the synchronous RuntimeHostV1 is correct.

Night Circuit runs inside a separate Godot process. Its P3 seat is a TCP
transport, so bridge calls are asynchronous.

NC-019 therefore consumes the merged PixelForge AsyncRuntimeHostV1 rather than
pretending sockets are synchronous function calls.

## Existing seat remains authoritative

The P3 server remains:

- loopback-only,
- single-client,
- source-locked to `agent`,
- actor-locked to `phi_bot`,
- action-rate-limited,
- routed through PlayerProtocol,
- routed through ActionBus,
- routed through AuthorityGate,
- subject to Φ-Bot capability state.

The PixelForge bridge client does not create Hunter authority.

## Runtime Bridge mapping

The Node-side P3 bridge exposes the standard Runtime Bridge v1 methods:

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

The transport maps:

- `observe()` -> P3 OBSERVE `phi_bot`
- `submit()` -> local queued root
- `advance()` -> P3 ACT request(s)
- P3 decision/effect receipts -> PixelForge runtime events

The bridge descriptor truthfully reports:

```text
deterministic = false
clockMode = engine
advanceSemantics = flush-controller-batch
replayExact = false
transport = tcp-jsonl
```

## CI qualification

The CI job launches the real Night Circuit Godot project headlessly.

The Node qualification then:

1. connects to the real P3 TCP seat,
2. uses the exact merged PixelForge SDK commit,
3. attaches a PixelForge model controller to Φ-Bot,
4. receives a real bounded Φ-Bot observation,
5. verifies HOLD is currently available,
6. feeds that observation through OllamaProviderV1 using a fake Ollama HTTP
   transport,
7. parses one HOLD intent through ModelPolicyClientV1,
8. submits it through AsyncRuntimeHostV1,
9. crosses TCP into the real Godot process,
10. requires native authority acceptance,
11. requires the Φ-Bot effect receipt `applied / hold_enabled`,
12. observes Φ-Bot again and requires `state.mode = HOLD`,
13. requires `control_source = agent`.

A negative-control model returns malformed prose. The policy must fail before any
new game action is submitted.

## Evidence streams

The qualification keeps three evidence layers distinct:

```text
Model Policy receipts
        |
Async Runtime Host receipts
        |
P3 / ActionBus / ReceiptLedger game evidence
```

The local PixelForge bridge recording stores submitted roots but does not claim
exact replay because Godot owns the simulation clock.

## Live local Ollama qualification

Run Night Circuit normally first so the HUD reports the agent seat listening on
127.0.0.1:36970.

Then from `tools/pixelforge`:

```powershell
npm install
$env:OLLAMA_MODEL="your-installed-model"
npm run qualify:ollama
```

The live model must return one HOLD intent. PASS requires an accepted P3 action,
an applied `hold_enabled` effect, and a subsequent bounded observation showing
Φ-Bot in HOLD mode.

## Non-goals

NC-019 does not add:

- a second network listener,
- Hunter control,
- authentication or internet exposure,
- model-provider code inside Godot,
- exact replay claims,
- autonomous continuous play,
- hidden repair of malformed model output.
