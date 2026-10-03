# Φ: Night Circuit

**An agent-native Metroidvania where human and AI players explore the same world through different senses.**

Night Circuit combines deliberate 2D exploration, towns that change with the night cycle, hidden routes, evidence-driven mysteries, and a physical AI companion called **Φ-Bot**.

> An agent is never merely dialogue. If it inhabits the world, it can act upon the world.

## Current milestone: NC-006 — Action Bus Hardening

NC-006 makes the command lifecycle auditable end to end.

Every proposal now moves through:

```text
INPUT SOURCE
    |
    v
TYPED ACTION CONTRACT
    |
    v
AUTHORITY GATE
    |
    +---- decision receipt
    |
    v
REGISTERED ACTOR EXECUTOR
    |
    +---- effect receipt
    |
    v
REPLAY-ORIENTED LEDGER
```

A command being authorized no longer gets confused with a command actually doing something. Humanity has spent enough decades learning that distinction in distributed systems.

### What is new

- versioned action envelope
- generated action IDs
- optional request-ID deduplication
- typed payload validation
- registered actor executors
- separate decision and effect receipts
- effect statuses: applied / noop / refused / failed
- accepted-action replay tape
- replay submissions travel through the same governed bus

### Visible example

Press **P** for Φ-Bot PING.

In Broken Form:

```text
DECISION: ACCEPTED
EFFECT: REFUSED
reason: ability_unavailable_in_broken_form
```

That is intentional. PING is a legitimate Φ-Bot capability surface, but Broken Form does not possess the installed ability yet.

## Controls

| Input | Action |
|---|---|
| A / D or arrows | Move |
| Space / W / Up | Jump / wall kick |
| S / Down | Crouch / ledge drop |
| J / Z | Light attack |
| K / X | Heavy attack |
| C / L | Dodge |
| F | Φ-Bot Follow |
| H | Φ-Bot Hold |
| Q | Φ-Bot Light |
| E | Φ-Bot Inspect |
| P | Φ-Bot PING test |

## Next rung

**NC-007 — Φ Player Protocol:** formalize the observation/action schemas and adapter boundary that an external agent seat will consume.

## License

MIT. See [LICENSE](LICENSE).
