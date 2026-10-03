from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

main = (ROOT / "game/main/main.gd").read_text(encoding="utf-8")
required = [
    'var boss_done: bool = bool(ledger.call("has_record"',
    'var scout_done: bool = bool(ledger.call("has_record"',
    'var route_done: bool = bool(ledger.call("has_record"',
    'var vein_done: bool = bool(ledger.call("has_record"',
    'var altermath_done: bool = bool(ledger.call("has_record"',
]
missing = [token for token in required if token not in main]
if missing:
    print("NC-017 local boot fix is incomplete:")
    for token in missing:
        print(f"  - {token}")
    sys.exit(1)

test = (ROOT / "tests/qualification/runtime_integration_smoke.gd").read_text(encoding="utf-8")
if 'preload("res://game/main/main.gd")' not in test:
    print("NC-017 integration smoke does not force-parse main.gd.")
    sys.exit(1)

print("NC-017 local first-boot regression validation: PASS")
