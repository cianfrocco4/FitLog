#!/usr/bin/env python3
"""Print `<name>\\n<udid>` for the preferred available iPhone simulator."""

from __future__ import annotations

import json
import subprocess
import sys


def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True)


def main() -> int:
    data = json.loads(run(["xcrun", "simctl", "list", "devices", "available", "-j"]))
    devices: list[tuple[str, str, str]] = []
    for runtime, items in data.get("devices", {}).items():
        for d in items:
            if d.get("isAvailable") is False:
                continue
            name = d.get("name") or ""
            if not name.startswith("iPhone"):
                continue
            devices.append((name, d["udid"], runtime))

    if not devices:
        print("No available iPhone simulators from simctl:", file=sys.stderr)
        print(run(["xcrun", "simctl", "list", "devices", "available"]), file=sys.stderr)
        return 1

    preferred = [
        "iPhone 16",
        "iPhone 16 Pro",
        "iPhone 15",
        "iPhone 15 Pro",
        "iPhone 17",
        "iPhone 17 Pro",
        "iPhone SE",
    ]

    def rank(item: tuple[str, str, str]) -> tuple[int, str]:
        name, _udid, _runtime = item
        for i, pref in enumerate(preferred):
            if name == pref or name.startswith(pref + " "):
                return (i, name)
        return (len(preferred), name)

    name, udid, runtime = sorted(devices, key=rank)[0]
    print(f"Using simulator: {name} ({udid}) runtime={runtime}", file=sys.stderr)
    print(name)
    print(udid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
