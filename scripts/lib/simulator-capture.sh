#!/bin/bash
#
# simulator-capture.sh
# Shared simulator screenshot-capture pipeline, sourced by
# generate-appstore-screenshots.sh and generate-screenshots.sh.
#
# Provides the common simctl/xcodebuild/xcresulttool steps plus the single
# manifest parser both generators use. Callers keep their own error/exit
# semantics (the App Store generator refuses partial sets and fails hard; the
# docs generator warns and continues to salvage whatever rendered).
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/simulator-capture.sh"

# Colors for output (consumed by the sourcing generator scripts).
# shellcheck disable=SC2034
GREEN='\033[0;32m'
# shellcheck disable=SC2034
BLUE='\033[0;34m'
# shellcheck disable=SC2034
RED='\033[0;31m'
# shellcheck disable=SC2034
NC='\033[0m' # No Color

# Resolves a simulator UDID by exact device name (available devices only).
# Prints the UDID, or nothing if no matching available device exists.
sim_udid_for_name() {
    local name="$1"
    xcrun simctl list devices available -j | python3 -c "
import json, sys
name = sys.argv[1]
devices = json.load(sys.stdin)['devices']
for runtime_devices in devices.values():
    for d in runtime_devices:
        if d.get('name') == name and d.get('isAvailable', True):
            print(d['udid'])
            raise SystemExit(0)
raise SystemExit(1)
" "$name" 2>/dev/null || true
}

# Boots the simulator and blocks until it has finished booting.
sim_boot_and_wait() {
    local udid="$1"
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b 2>/dev/null || true
}

# Overrides the status bar to Apple's standard 9:41 / full battery so
# screenshots are deterministic.
sim_status_bar_941() {
    xcrun simctl status_bar "$1" override --time "9:41" --batteryState charged --batteryLevel 100
}

# Clears any status-bar override. Best-effort — never fails the caller.
sim_status_bar_clear() {
    xcrun simctl status_bar "$1" clear 2>/dev/null || true
}

# Runs the screenshot UI test and returns xcodebuild's real exit code.
# `$?` after the pipe is the formatter's exit code (always 0), so we recover
# xcodebuild's via PIPESTATUS. Callers decide what a non-zero result means.
run_screenshot_tests() {
    local scheme="$1" destination="$2" test_target="$3" derived_data="$4"
    rm -rf "$derived_data"
    local result
    set +e
    xcodebuild test \
        -scheme "$scheme" \
        -destination "$destination" \
        -only-testing:"$test_target" \
        -derivedDataPath "$derived_data" \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | if command -v xcpretty >/dev/null; then xcpretty --color; else cat; fi
    result=${PIPESTATUS[0]}
    set -e
    return "$result"
}

# Prints the first .xcresult bundle under the given derived-data path (empty
# if none). Callers guard against the empty case with their own message.
find_xcresult_bundle() {
    find "$1" -name "*.xcresult" -type d | head -n 1
}

# Exports all attachments from an .xcresult bundle into a fresh output dir.
export_xcresult_attachments() {
    local bundle="$1" out="$2"
    rm -rf "$out"
    mkdir -p "$out"
    xcrun xcresulttool export attachments --path "$bundle" --output-path "$out"
}

# The single manifest parser both generators share. xcresulttool exports
# attachments under opaque UUID filenames; the human-readable name (which
# embeds the screenshot number, e.g. …-keyboard-01-…) only exists in
# manifest.json. A naive top-level read misses attachments nested at varying
# depths, so this walks the whole tree. Emits one tab-separated
# `suggestedHumanReadableName<TAB>exportedFileName` line per attachment,
# sorted by the human-readable name (i.e. in screenshot order).
manifest_names_to_files() {
    python3 - "$1" <<'PYEOF'
import json
import sys


def walk(node, out):
    if isinstance(node, dict):
        if "exportedFileName" in node and "suggestedHumanReadableName" in node:
            out.append((node["suggestedHumanReadableName"], node["exportedFileName"]))
        for value in node.values():
            walk(value, out)
    elif isinstance(node, list):
        for value in node:
            walk(value, out)


attachments = []
with open(sys.argv[1]) as f:
    walk(json.load(f), attachments)
for suggested, exported in sorted(attachments):
    print(f"{suggested}\t{exported}")
PYEOF
}
