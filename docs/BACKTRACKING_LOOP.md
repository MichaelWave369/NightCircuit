# NC-014 Backtracking Loop

NC-014 closes the first real Metroidvania progression loop.

The player earns Scout from The Fallen, returns through old sewer terrain, and discovers that Intake Shaft was never fully understood.

## Loop

```text
THE FALLEN
   |
SCOUT CORE
   |
return to CISTERN APPROACH
   |
walk back through SPILLWAY
   |
INTAKE SHAFT
   |
PING
   |
intake_anchor_01
   |
MARK
   |
geometry reconstructs
   |
climb SERVICE VEIN
```

Nothing in the original Intake Shaft controls changes. The meaning of the room changes because Φ-Bot can now sense and act on structure that was previously unavailable.

## Dormant anchor

Scout Ping can detect:

```text
object_id: intake_anchor_01
category: anchor_resonance
classification: dormant_geometry_anchor
confidence: 0.96
markable: true
```

The signal does not exist before Scout is verified in the Reality Ledger.

## Governed unlock

Marking the anchor still uses the normal action path:

```text
P / G or external P3 ACT
        |
        v
Human / Agent adapter
        |
        v
Action Bus
        |
Authority Gate
        |
Φ-Bot MARK executor
        |
active world validates anchor
        |
geometry mutation + receipt
```

The world validates the target, range, and Scout progression before changing geometry.

## Route mutation

A successful mark reconstructs a sequence of upper service platforms in Intake Shaft.

That creates a traversal route to an unmapped Service Vein.

The route opening is persisted as:

```text
type: verified
subject: intake_anchor_01
value: route_open
```

So the geometry remains open after restart.

## Discovery

Entering the Service Vein creates evidence:

```text
type: evidence
subject: service_vein_01
value: discovered
source: hunter / direct_traversal
```

The Service Vein leaves behind a lower-confidence signal called `keyhole_residue_01`.

Its classification is deliberately unresolved:

```text
category: causal_residue
classification: cause_unknown
confidence: 0.71
```

That is a teaser, not an answer.

## P3

The sewer now provides a world-state snapshot with:

- whether Scout is unlocked
- whether the Intake anchor route is open
- whether Service Vein has been discovered
- stable anchor/route IDs

External Φ-Bot agents can therefore execute the same:

```text
OBSERVE
PING
MARK intake_anchor_01
OBSERVE
```

No separate agent-only route exists.

## NC-015 handoff

The vertical-slice qualification rung can now test a genuine closed progression loop:

- start in the Drain
- reach Ash Village
- experience phase mutation and testimony
- fight The Fallen
- acquire Scout
- backtrack
- use Scout on old terrain
- discover the first new route
