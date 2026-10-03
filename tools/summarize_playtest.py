#!/usr/bin/env python3
"""Summarize a Night Circuit playtest NDJSON log."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def load_events(path: Path) -> list[dict]:
    events: list[dict] = []
    for line_number, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw.strip()
        if not line:
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            raise SystemExit(f"{path}:{line_number}: invalid JSON: {exc}") from exc
        if isinstance(value, dict):
            events.append(value)
    return events


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("log", type=Path)
    args = parser.parse_args()

    events = load_events(args.log)
    counts = Counter(str(event.get("event", "unknown")) for event in events)

    duration_ms = 0
    if events:
        duration_ms = max(int(event.get("elapsed_ms", 0)) for event in events)

    print("Night Circuit playtest summary")
    print(f"log: {args.log}")
    print(f"events: {len(events)}")
    print(f"duration_seconds: {duration_ms / 1000.0:.1f}")
    print("event_counts:")
    for name, count in sorted(counts.items()):
        print(f"  {name}: {count}")

    effects = [
        event.get("data", {})
        for event in events
        if event.get("event") == "action.effect"
    ]
    refused = [data for data in effects if data.get("status") in {"refused", "failed"}]
    if refused:
        print("action_failures:")
        for data in refused[-20:]:
            print(
                "  "
                f"{data.get('actor', '?')}.{data.get('action', '?')} "
                f"{data.get('status', '?')} "
                f"({data.get('reason', '?')})"
            )

    markers = [
        event.get("data", {}).get("label", "")
        for event in events
        if event.get("event") == "tester.marker"
    ]
    if markers:
        print("tester_markers:")
        for marker in markers:
            print(f"  {marker}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
