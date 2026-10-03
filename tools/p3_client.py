#!/usr/bin/env python3
"""Small dependency-free client for the Night Circuit local P3 agent seat."""

from __future__ import annotations

import argparse
import json
import socket
import sys
import uuid
from typing import Any

HOST = "127.0.0.1"
DEFAULT_PORT = 36970
MAX_RESPONSE_BYTES = 1024 * 1024


class P3Client:
    def __init__(self, port: int = DEFAULT_PORT, timeout: float = 5.0) -> None:
        self.port = port
        self.timeout = timeout
        self._socket: socket.socket | None = None
        self._file = None

    def __enter__(self) -> "P3Client":
        self.connect()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def connect(self) -> None:
        if self._socket is not None:
            return
        self._socket = socket.create_connection((HOST, self.port), timeout=self.timeout)
        self._file = self._socket.makefile("rwb")

    def close(self) -> None:
        if self._file is not None:
            self._file.close()
            self._file = None
        if self._socket is not None:
            self._socket.close()
            self._socket = None

    def request(self, message: dict[str, Any]) -> dict[str, Any]:
        self.connect()
        assert self._file is not None

        outbound = dict(message)
        outbound.setdefault("request_id", f"cli-{uuid.uuid4().hex[:12]}")

        wire = (json.dumps(outbound, separators=(",", ":")) + "\n").encode("utf-8")
        self._file.write(wire)
        self._file.flush()

        line = self._file.readline(MAX_RESPONSE_BYTES)
        if not line:
            raise RuntimeError("Night Circuit closed the local agent connection without a response.")
        if not line.endswith(b"\n"):
            raise RuntimeError("P3 response exceeded the client safety limit.")

        response = json.loads(line.decode("utf-8"))
        if not isinstance(response, dict):
            raise RuntimeError("P3 response was not a JSON object.")
        return response


def parse_payload(raw: str) -> dict[str, Any]:
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid --payload JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise SystemExit("--payload must decode to a JSON object.")
    return value


def build_message(args: argparse.Namespace) -> dict[str, Any]:
    if args.command == "describe":
        return {"type": "describe"}

    if args.command == "observe":
        return {"type": "observe", "actor": "phi_bot"}

    if args.command == "act":
        return {
            "type": "act",
            "actor": "phi_bot",
            "action": args.action.upper(),
            "payload": parse_payload(args.payload),
        }

    raise SystemExit(f"Unsupported command: {args.command}")


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        description="Talk to Night Circuit's loopback-only P3 agent seat."
    )
    root.add_argument("--port", type=int, default=DEFAULT_PORT)

    sub = root.add_subparsers(dest="command", required=True)
    sub.add_parser("describe", help="Read the P3 handshake and seat contract.")
    sub.add_parser("observe", help="Request a scoped Φ-Bot observation.")

    act = sub.add_parser("act", help="Submit one governed Φ-Bot action.")
    act.add_argument("action", help="P3 action such as FOLLOW, HOLD, LIGHT, or INSPECT.")
    act.add_argument(
        "--payload",
        default="{}",
        help='JSON object payload, for example: \'{"toggle": true}\'',
    )
    return root


def main() -> int:
    args = parser().parse_args()
    message = build_message(args)

    try:
        with P3Client(port=args.port) as client:
            response = client.request(message)
    except (OSError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"P3 client error: {exc}", file=sys.stderr)
        return 2

    print(json.dumps(response, indent=2, sort_keys=True))
    return 0 if response.get("ok", False) else 1


if __name__ == "__main__":
    raise SystemExit(main())
