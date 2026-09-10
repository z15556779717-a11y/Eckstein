#!/usr/bin/env python3
"""Print the UDID of the best available iOS simulator, or nothing.

Used by .github/workflows/ios.yml. GitHub's macOS images change the set of
installed simulator runtimes without notice (the iOS 18.4 runtime was removed
in Jan 2026), so the workflow must not hardcode a destination. This picks the
newest installed iOS runtime and the first available iPhone on it.

The project's IPHONEOS_DEPLOYMENT_TARGET (18.4) is *older* than or equal to
whatever runtime is newest, so any iPhone on the newest runtime can install
the build. Picking the newest avoids the reverse failure: an iPhone on an
older runtime refusing an app whose deployment target it does not meet.

Exit status is 0 and stdout is empty when no suitable simulator exists; the
workflow turns that into a hard error with the full device list.
"""

import json
import subprocess
import sys

RUNTIME_PREFIX = "com.apple.CoreSimulator.SimRuntime.iOS-"


def runtime_version(runtime_id):
    """Sort key for a runtime identifier: 'iOS-18-5' -> [18, 5]."""
    if not runtime_id.startswith(RUNTIME_PREFIX):
        return None
    suffix = runtime_id[len(RUNTIME_PREFIX):]
    parts = []
    for chunk in suffix.split("-"):
        if not chunk.isdigit():
            return None
        parts.append(int(chunk))
    return parts or None


def main():
    listing = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    devices_by_runtime = json.loads(listing)["devices"]

    candidates = []
    for runtime_id, devices in devices_by_runtime.items():
        version = runtime_version(runtime_id)
        if version is None:
            continue
        for device in devices:
            if device.get("isAvailable") and device["name"].startswith("iPhone"):
                candidates.append((version, device["name"], device["udid"]))
                break

    if not candidates:
        return ""
    return max(candidates)[2]


if __name__ == "__main__":
    sys.stdout.write(main())
