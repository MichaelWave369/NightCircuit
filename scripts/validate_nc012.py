from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-012 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/actors/bosses/the_fallen/the_fallen.gd",
    [
        "PHASE_TWO_THRESHOLD",
        "WHIP_STRIKE",
        "GROUND_SWEEP",
        "CROSS_THROW",
        "BELL_LEAP",
        "CAUSAL_ECHO",
        "NO_PHYSICAL_SOURCE",
        "physical_hitbox.activate",
        "projectile_hitbox.activate",
        "causal_hitbox.activate",
        "history_offset_frames",
        "phase_changed",
        "anomaly_detected",
        "defeated.emit",
        "actor_snapshot",
    ],
)

require_tokens(
    "game/actors/bosses/the_fallen/TheFallen.tscn",
    [
        'groups=["enemy", "boss"]',
        "Hurtbox",
        "PhysicalHitbox",
        "ProjectileHitbox",
        "CausalHitbox",
    ],
)

require_tokens(
    "game/world/fallen_arena/fallen_arena.gd",
    [
        "VIGIL_CACHE_POSITION",
        "SCOUT_CORE_POSITION",
        "boss_anomaly",
        "boss_defeated",
        "protocol_signals",
        "fallen_causal_attack",
        "scout_core_unclaimed",
        "restore_full_health",
        'exit_requested.emit("sewer_from_fallen")',
    ],
)

require_tokens(
    "game/world/sewer_test/sewer_test_room.gd",
    [
        "BOSS_GATE_POSITION",
        "interact_nearest",
        'exit_requested.emit("fallen_arena")',
        "enter_from_boss",
        "ENTER FALLEN CISTERN",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "FallenArena.tscn",
        'name="FallenArena"',
        "BossState",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        "fallen_arena.bind_hunter",
        "sewer_world.enter_from_boss",
        "_on_boss_anomaly",
        "NO PHYSICAL SOURCE",
        "_on_boss_defeated",
        'record_observation({',
        'record_evidence({',
        "_update_boss_readout",
    ],
)

require_tokens(
    "game/protocol/runtime_observation_provider.gd",
    [
        '"boss_phase"',
        '"attack"',
        '"physical_source"',
    ],
)

print("NC-012 The Fallen validation: PASS")
