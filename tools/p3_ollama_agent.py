#!/usr/bin/env python3
"""Optional local Ollama agent that plays the Φ-Bot seat through P3."""

from __future__ import annotations

import argparse
import json
import os
import time
import urllib.error
import urllib.request
from typing import Any

from p3_client import DEFAULT_PORT, P3Client

OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
DEFAULT_MODEL = os.environ.get("NIGHTCIRCUIT_OLLAMA_MODEL", "qwen3:4b")

SYSTEM_PROMPT = """You control Φ-Bot in the game Night Circuit.
You are not the Hunter and cannot control the Hunter.
Choose exactly one action from the capability map whose available field is true.
Prefer useful observation-driven behavior: follow the Hunter, inspect nearby anomaly signals,
use light when it helps, or hold when separation is useful.
Return only a JSON object with this shape:
{"action":"FOLLOW","payload":{}}
Do not include prose or markdown.
"""


def call_ollama(model: str, observation: dict[str, Any], timeout: float) -> dict[str, Any]:
    capabilities = observation.get("capabilities", {})
    available = {
        name: detail
        for name, detail in capabilities.items()
        if isinstance(detail, dict) and detail.get("available") is True
    }

    user_prompt = {
        "available_actions": available,
        "observation": observation,
    }

    body = {
        "model": model,
        "stream": False,
        "format": "json",
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": json.dumps(user_prompt, separators=(",", ":"))},
        ],
        "options": {"temperature": 0.2},
    }

    request = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    with urllib.request.urlopen(request, timeout=timeout) as response:
        decoded = json.loads(response.read().decode("utf-8"))

    content = decoded.get("message", {}).get("content", "{}")
    choice = json.loads(content)
    if not isinstance(choice, dict):
        raise ValueError("Ollama choice was not a JSON object.")
    return choice


def sanitize_choice(
    choice: dict[str, Any], observation: dict[str, Any]
) -> tuple[str, dict[str, Any]]:
    capabilities = observation.get("capabilities", {})
    action = str(choice.get("action", "")).upper()
    payload = choice.get("payload", {})

    detail = capabilities.get(action, {})
    if not isinstance(detail, dict) or detail.get("available") is not True:
        return "HOLD", {}

    if not isinstance(payload, dict):
        payload = {}

    return action, payload


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        description="Let a local Ollama model occupy the governed Φ-Bot P3 seat."
    )
    root.add_argument("--model", default=DEFAULT_MODEL)
    root.add_argument("--steps", type=int, default=30)
    root.add_argument("--interval", type=float, default=0.45)
    root.add_argument("--port", type=int, default=DEFAULT_PORT)
    root.add_argument("--ollama-timeout", type=float, default=60.0)
    return root


def main() -> int:
    args = parser().parse_args()

    try:
        with P3Client(port=args.port, timeout=5.0) as client:
            description = client.request({"type": "describe"})
            if not description.get("ok", False):
                print(json.dumps(description, indent=2))
                return 1

            seat = description.get("body", {}).get("seat", {})
            print(
                f"P3 seat connected: actor={seat.get('actor')} "
                f"transport={seat.get('transport')} port={seat.get('port')}"
            )

            for step in range(1, max(1, args.steps) + 1):
                observed = client.request({"type": "observe", "actor": "phi_bot"})
                if not observed.get("ok", False):
                    print(json.dumps(observed, indent=2))
                    return 1

                observation = observed.get("body", {}).get("observation", {})

                try:
                    choice = call_ollama(args.model, observation, args.ollama_timeout)
                    action, payload = sanitize_choice(choice, observation)
                except (urllib.error.URLError, TimeoutError, ValueError, json.JSONDecodeError) as exc:
                    print(f"[{step:03d}] Ollama decision failed: {exc}; falling back to HOLD")
                    action, payload = "HOLD", {}

                result = client.request(
                    {
                        "type": "act",
                        "actor": "phi_bot",
                        "action": action,
                        "payload": payload,
                    }
                )

                effect = result.get("body", {}).get("effect", {})
                print(
                    f"[{step:03d}] {action} -> "
                    f"{effect.get('status', '?')} ({effect.get('reason', '?')})"
                )
                time.sleep(max(0.05, args.interval))

    except (OSError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"Agent seat error: {exc}")
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
