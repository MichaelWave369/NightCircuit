# Roadmap

## Progress

- **NC-001 — COMPLETE:** agent-native Godot skeleton, authority seam, receipts
- **NC-002 — COMPLETE:** Hunter movement controller and governed human input
- **NC-003 — COMPLETE:** sewer traversal greybox, camera, checkpoints, room flow
- **NC-004 — COMPLETE:** combat, health/damage, dodge, Drain Husk
- **NC-005 — COMPLETE:** embodied Φ-Bot with follow, hold, light, inspect
- **NC-006 — COMPLETE:** typed actions, actor dispatch, effect receipts, replay semantics
- **NC-007 — COMPLETE:** P3 describe/observe/act boundary and actor-scoped observations
- **NC-008 — COMPLETE IN THIS CHANGE:** loopback external Φ-Bot seat and local model bridge
- **NC-009 — NEXT:** Ash Village

## Vertical-slice ladder

| Rung | Goal | Exit condition |
|---|---|---|
| NC-001 | Project skeleton | Godot project boots; governed PING returns a receipt |
| NC-002 | Hunter controller | run, jump, crouch, ledge grab, wall kick |
| NC-003 | Sewer test room | traversal greybox with camera and checkpoints |
| NC-004 | Combat | light/heavy/dodge + damage contract |
| NC-005 | Φ-Bot entity | follow, hold, light, inspect |
| NC-006 | Action Bus hardening | typed actions, actor execution, effect receipts |
| NC-007 | Φ Player Protocol | describe/observe/act schemas and adapter boundary |
| NC-008 | Agent seat | local external process can observe/control Φ-Bot and cannot cross into Hunter |
| NC-009 | Ash Village | NPC schedules and first hub loop |
| NC-010 | Day/night | state transition changes routes and actors |
| NC-011 | Reality Ledger | evidence, claims, provenance, contradictions |
| NC-012 | The Fallen | complete first boss encounter |
| NC-013 | Scout Core | ping, mark, enemy read, contradiction sense |
| NC-014 | Backtracking loop | Scout opens meaningful old-route discoveries |
| NC-015 | Vertical Slice 0.1 | The Drain is playable start to finish |

## Rule

Do not expand into the full castle before NC-015 passes.

Feature creep already has enough employment opportunities.
