#!/bin/sh
# Uses a booted watch simulator; no app install, microphone, network, or private recordings.
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bb-watch-playback.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT
trap 'exit 1' HUP INT TERM
xcrun --sdk watchsimulator swiftc -swift-version 6 \
    -target arm64-apple-watchos26.0-simulator \
    "$SCRIPT_DIR/Sources/BBWatchCore/DurableStore.swift" \
    "$SCRIPT_DIR/Sources/BBWatch/AudioPlayback.swift" \
    "$SCRIPT_DIR/Checks/AudioPlaybackCheck.swift" \
    -o "$TMP_DIR/AudioPlaybackCheck"
if [ -z "${PLAYBACK_SIMULATOR:-}" ]; then
    xcrun simctl list devices booted --json > "$TMP_DIR/devices.json"
    PLAYBACK_SIMULATOR=$(python3 - "$TMP_DIR/devices.json" <<'PYDEVICES'
import json
import sys
with open(sys.argv[1]) as source:
    devices = json.load(source)["devices"]
watches = [device["udid"] for runtime, rows in devices.items() if "watchOS" in runtime
           for device in rows if device.get("isAvailable") and device["state"] == "Booted"]
if len(watches) != 1:
    sys.exit("Boot exactly one available watch simulator, or set PLAYBACK_SIMULATOR to its UDID.")
print(watches[0])
PYDEVICES
    )
fi
xcrun simctl spawn "$PLAYBACK_SIMULATOR" "$TMP_DIR/AudioPlaybackCheck"
