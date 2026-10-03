from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-011 contract tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/reality/reality_ledger.gd",
    [
        "night-circuit/reality-ledger/0.1",
        "user://night_circuit_reality_ledger_v1.json",
        '"claim"',
        '"observation"',
        '"evidence"',
        '"inference"',
        '"contradiction"',
        '"verified"',
        "record_claim",
        "record_observation",
        "record_evidence",
        "add_inference",
        "mark_verified",
        "_derive_contradictions",
        "same_subject_different_value",
        "public_summary",
        "_save_to_disk",
        "_load_from_disk",
        "repeat_count",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        'get_node_or_null("/root/RealityLedger")',
        "_record_testimony",
        "record_claim",
        "_record_phase_observation",
        "record_observation",
        "record_evidence",
        "_on_contradiction_detected",
        "_update_ledger_readout",
    ],
)

require_tokens(
    "game/protocol/runtime_observation_provider.gd",
    [
        '"reality_ledger"',
        "_ledger_summary",
        "public_summary",
    ],
)

require_tokens(
    "game/main/Main.tscn",
    [
        "LedgerState",
    ],
)

project = (ROOT / "project.godot").read_text(encoding="utf-8")
if 'RealityLedger="*res://game/reality/reality_ledger.gd"' not in project:
    print("RealityLedger autoload is missing.")
    sys.exit(1)

village = (ROOT / "game/world/ash_village/ash_village.gd").read_text(encoding="utf-8")
for marker in ("bridge_destroyed_long_ago", "bridge_present_today"):
    if marker not in village:
        print(f"Bridge contradiction seed missing: {marker}")
        sys.exit(1)

print("NC-011 Reality Ledger validation: PASS")
