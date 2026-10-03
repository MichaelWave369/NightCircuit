from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

def require_tokens(path: str, tokens: list[str]) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    missing = [token for token in tokens if token not in text]
    if missing:
        print(f"{path} is missing NC-016 playtest tokens:")
        for token in missing:
            print(f"  - {token}")
        sys.exit(1)

require_tokens(
    "game/qualification/playtest_recorder.gd",
    [
        "night-circuit/playtest-event/0.1",
        "night-circuit/playtest-summary/0.1",
        "user://playtests",
        "record_event",
        "tester.marker",
        "action.effect",
        "reality.record_added",
        "run_save.written",
        "p3.observation",
        "export_summary",
    ],
)

require_tokens(
    "game/main/main.gd",
    [
        '"milestone": "NC-016"',
        "_record_playtest_event",
        "world.transition_requested",
        "hunter.defeated",
        "boss.anomaly",
        "boss.defeated",
        "scout.core_claimed",
        "backtrack.route_opened",
        "backtrack.discovery",
        "slice.altermath_teaser",
        "KEY_F7",
        "KEY_F8",
        "_export_playtest_summary",
    ],
)

require_tokens(
    "tests/qualification/runtime_integration_smoke.gd",
    [
        "_test_run_save_roundtrip",
        "RealityLedger",
        "integration_bridge",
        "contradictions.size() == 1",
        "runtime integration smoke: PASS",
    ],
)

require_tokens(
    "tools/summarize_playtest.py",
    [
        "Night Circuit playtest summary",
        "action_failures",
        "tester_markers",
    ],
)

project = (ROOT / "project.godot").read_text(encoding="utf-8")
if 'PlaytestRecorder="*res://game/qualification/playtest_recorder.gd"' not in project:
    print("PlaytestRecorder autoload is missing.")
    sys.exit(1)

workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
for marker in (
    "Validate NC-016 playtest harness",
    "Godot runtime integration smoke",
    "runtime_integration_smoke.gd",
):
    if marker not in workflow:
        print(f"NC-016 workflow marker missing: {marker}")
        sys.exit(1)

print("NC-016 playtest harness validation: PASS")
