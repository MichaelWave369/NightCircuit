# NC-004 Combat Contract

NC-004 establishes combat as a reusable boundary rather than burying damage logic inside one enemy.

## Governed intent

The HumanInputAdapter emits:

- `LIGHT_ATTACK`
- `HEAVY_ATTACK`
- `DODGE`

through the existing Action Bus and Authority Gate.

The adapter never changes health, combat state, hitbox state, velocity, or position directly.

## Combat boundary

```text
authorized attack intent
        |
        v
      Hunter
        |
        v
      Hitbox
        |
        v
      Hurtbox
        |
        v
   receive_hit()
```

Hitboxes describe an attack event.

Hurtboxes decide whether a target is eligible to receive it.

The actor owns health, knockback response, invulnerability, death, and later status effects.

## Collision layers

NC-004 reserves:

- layer 1: world collision
- layer 2: Hunter body
- layer 16: combat hurtboxes
- layer 32: combat hitboxes
- layer 64: ordinary enemy bodies

Hitbox and hurtbox scripts also enforce team separation so sharing the combat layers does not permit self/friendly hits.

## Hunter attacks

### Light

- 14 damage
- 0.28 s total
- short active window
- light knockback

### Heavy

- 28 damage
- 0.52 s total
- later active window
- stronger knockback

### Dodge

- 0.30 s
- horizontal burst
- invulnerable during the dodge window

These are tuning values, not sacred scripture. Humans will inevitably argue about whether the dodge should be 16 milliseconds longer, as is our species' destiny.

## Damage

Hunter starts at 100 HP.

After taking a hit:

- health decreases
- current attack is cancelled
- brief hit-stun applies
- knockback applies
- short post-hit invulnerability prevents frame-rate-dependent blender deaths

Checkpoint respawn restores full health in the NC-004 prototype.

## Drain Husk

The first enemy exists to test the grammar:

1. detect Hunter
2. approach while preserving floor
3. stop inside attack range
4. visibly telegraph
5. activate attack hitbox
6. recover
7. repeat

Its attack phases are intentionally explicit:

`WINDUP -> ACTIVE -> RECOVERY -> READY`

That structure can later be observed by Φ-Bot and agent players.

## Deferred

NC-004 does not add:

- weapon inventory
- magic
- combos
- parry
- status effects
- enemy drops
- permanent enemy respawn rules
- boss logic

Those belong after the core hit/damage boundary survives actual play.
