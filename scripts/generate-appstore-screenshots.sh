#!/bin/bash
#
# generate-appstore-screenshots.sh
# Generate App Store screenshots in the flat per-locale layout that deliver
# uploads: fastlane/screenshots/<locale>/<size>_<NN>.png. deliver infers the
# device class from the pixel dimensions, so there must be NO subdirectories
# below the locale folder (nested APP_IPHONE_* folders are silently ignored).
#
# Rendered natively per device — no sips scaling, the display classes have
# slightly different aspect ratios:
# - 69: iPhone 17 Pro Max (1320 x 2868, 6.9")
# - 61: iPhone 16e       (1170 x 2532, 6.1")
#
# The screenshot content is locale-independent (the chat mock is English),
# so the en-US set is mirrored to de-DE.
#
# Usage: ./scripts/generate-appstore-screenshots.sh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📱 Wurstfinger App Store Screenshot Generator${NC}"
echo ""

# Change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Configuration
SCHEME="Wurstfinger"
TEST_TARGET="WurstfingerUITests/ScreenshotTests/testGenerateAppStoreKeyboardScreenshots"
SCREENSHOTS_ROOT="$PROJECT_ROOT/fastlane/screenshots"
PRIMARY_LOCALE="en-US"
MIRROR_LOCALES=("de-DE")
DERIVED_DATA="/tmp/WurstfingerAppStoreScreenshots"
TEMP_SCREENSHOTS="/tmp/wurstfinger-screenshots-raw"

# size-prefix|simulator device name
TARGETS=(
    "69|iPhone 17 Pro Max"
    "61|iPhone 16e"
)

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Output: $SCREENSHOTS_ROOT/<locale>/<size>_<NN>.png"
for target in "${TARGETS[@]}"; do
    echo "  - ${target%%|*}: ${target#*|}"
done
echo ""

# Get device UDID
get_device_udid() {
    local device_name="$1"
    xcrun simctl list devices available | grep "$device_name" | head -n 1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true
}

# Ensure cleanup runs on any exit (normal, error, or signal)
CURRENT_UDID=""
cleanup() {
    echo ""
    echo -e "${BLUE}🧹 Cleaning up...${NC}"
    if [ -n "$CURRENT_UDID" ]; then
        xcrun simctl status_bar "$CURRENT_UDID" clear 2>/dev/null || true
        xcrun simctl shutdown "$CURRENT_UDID" 2>/dev/null || true
    fi
    rm -rf "$DERIVED_DATA"
    rm -rf "$TEMP_SCREENSHOTS"
}
trap cleanup EXIT

PRIMARY_DIR="$SCREENSHOTS_ROOT/$PRIMARY_LOCALE"
mkdir -p "$PRIMARY_DIR"
rm -f "$PRIMARY_DIR"/*.png

for target in "${TARGETS[@]}"; do
    SIZE_PREFIX="${target%%|*}"
    DEVICE_NAME="${target#*|}"

    echo -e "${BLUE}🔄 Capturing $SIZE_PREFIX screenshots on $DEVICE_NAME${NC}"

    UDID=$(get_device_udid "$DEVICE_NAME")
    if [ -z "$UDID" ]; then
        echo -e "${RED}❌ Device not found: $DEVICE_NAME${NC}"
        echo "Available devices:"
        xcrun simctl list devices available | grep iPhone
        exit 1
    fi
    CURRENT_UDID="$UDID"
    echo "  UDID: $UDID"

    # Boot simulator
    echo "  Booting simulator..."
    xcrun simctl boot "$UDID" 2>/dev/null || true
    xcrun simctl bootstatus "$UDID" -b 2>/dev/null || true

    # Override status bar to get consistent screenshots (Apple's standard 9:41)
    echo "  Setting consistent status bar..."
    xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100

    # Run screenshot tests
    echo "  Running screenshot tests..."
    rm -rf "$DERIVED_DATA"

    set +e
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$UDID" \
        -only-testing:"$TEST_TARGET" \
        -derivedDataPath "$DERIVED_DATA" \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | if command -v xcpretty >/dev/null; then xcpretty --color; else cat; fi
    TEST_RESULT=$?
    set -e

    if [ $TEST_RESULT -ne 0 ]; then
        echo -e "${YELLOW}⚠️  Tests may have issues, checking for screenshots...${NC}"
    fi

    # Find and extract screenshots from xcresult
    RESULTS_BUNDLE=$(find "$DERIVED_DATA" -name "*.xcresult" -type d | head -n 1)
    if [ -z "$RESULTS_BUNDLE" ]; then
        echo -e "${RED}❌ No results bundle found${NC}"
        exit 1
    fi

    rm -rf "$TEMP_SCREENSHOTS"
    mkdir -p "$TEMP_SCREENSHOTS"
    xcrun xcresulttool export attachments --path "$RESULTS_BUNDLE" --output-path "$TEMP_SCREENSHOTS"

    PNG_COUNT=$(find "$TEMP_SCREENSHOTS" -name "*.png" -type f | wc -l | tr -d ' ')
    echo "  Found $PNG_COUNT PNG files"
    if [ "$PNG_COUNT" -eq 0 ]; then
        echo -e "${RED}❌ No screenshots found for $DEVICE_NAME${NC}"
        exit 1
    fi

    # xcresulttool exports attachments under opaque UUID filenames; the
    # attachment name (which embeds the screenshot number, …-keyboard-01-…)
    # only exists in manifest.json. Sorting the files directly would produce
    # a random screenshot order, so order by the manifest names instead.
    COUNTER=1
    while IFS= read -r exported; do
        filename=$(printf "%s_%02d.png" "$SIZE_PREFIX" $COUNTER)
        cp "$TEMP_SCREENSHOTS/$exported" "$PRIMARY_DIR/$filename"
        echo "    ✓ $filename ($exported)"
        COUNTER=$((COUNTER + 1))
    done < <(python3 - "$TEMP_SCREENSHOTS/manifest.json" <<'PYEOF'
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
if not attachments:
    sys.exit("manifest.json contained no attachments")
for _, exported in sorted(attachments):
    print(exported)
PYEOF
)

    # Shut down before switching to the next device
    xcrun simctl status_bar "$UDID" clear 2>/dev/null || true
    xcrun simctl shutdown "$UDID" 2>/dev/null || true
    CURRENT_UDID=""
    echo ""
done

# Mirror the primary locale to the others (content is locale-independent)
for locale in "${MIRROR_LOCALES[@]}"; do
    LOCALE_DIR="$SCREENSHOTS_ROOT/$locale"
    echo -e "${BLUE}🔄 Mirroring $PRIMARY_LOCALE → $locale${NC}"
    mkdir -p "$LOCALE_DIR"
    rm -f "$LOCALE_DIR"/*.png
    cp "$PRIMARY_DIR"/*.png "$LOCALE_DIR/"
done

# Summary
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
for locale in "$PRIMARY_LOCALE" "${MIRROR_LOCALES[@]}"; do
    count=$(find "$SCREENSHOTS_ROOT/$locale" -maxdepth 1 -name "*.png" -type f | wc -l | tr -d ' ')
    echo "  $locale: $count screenshots"
done

echo ""
echo -e "${GREEN}✅ App Store screenshots generated successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "  1. Review screenshots"
echo "  2. Commit and push"
echo "  3. Run fastlane release"
echo ""
echo -e "${GREEN}✨ Done!${NC}"
