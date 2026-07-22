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

# Change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/simulator-capture.sh
source "$SCRIPT_DIR/lib/simulator-capture.sh"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${BLUE}📱 Wurstfinger App Store Screenshot Generator${NC}"
echo ""

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

# Ensure cleanup runs on any exit (normal, error, or signal)
CURRENT_UDID=""
cleanup() {
    echo ""
    echo -e "${BLUE}🧹 Cleaning up...${NC}"
    if [ -n "$CURRENT_UDID" ]; then
        sim_status_bar_clear "$CURRENT_UDID"
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

    UDID=$(sim_udid_for_name "$DEVICE_NAME")
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
    sim_boot_and_wait "$UDID"

    # Override status bar to get consistent screenshots (Apple's standard 9:41)
    echo "  Setting consistent status bar..."
    sim_status_bar_941 "$UDID"

    # Run screenshot tests
    echo "  Running screenshot tests..."
    TEST_RESULT=0
    run_screenshot_tests \
        "$SCHEME" \
        "platform=iOS Simulator,id=$UDID" \
        "$TEST_TARGET" \
        "$DERIVED_DATA" || TEST_RESULT=$?

    if [ "$TEST_RESULT" -ne 0 ]; then
        # These screenshots ship to the App Store (deliver uploads with
        # overwrite_screenshots: true), so a partial set from a failed run
        # must never be used silently.
        echo -e "${RED}❌ Screenshot tests failed on $DEVICE_NAME (exit code: $TEST_RESULT)${NC}"
        echo -e "${RED}   Refusing to continue — a partial screenshot set must not ship.${NC}"
        exit 1
    fi

    # Find and extract screenshots from xcresult
    RESULTS_BUNDLE=$(find_xcresult_bundle "$DERIVED_DATA")
    if [ -z "$RESULTS_BUNDLE" ]; then
        echo -e "${RED}❌ No results bundle found${NC}"
        exit 1
    fi

    export_xcresult_attachments "$RESULTS_BUNDLE" "$TEMP_SCREENSHOTS"

    PNG_COUNT=$(find "$TEMP_SCREENSHOTS" -name "*.png" -type f | wc -l | tr -d ' ')
    echo "  Found $PNG_COUNT PNG files"
    if [ "$PNG_COUNT" -eq 0 ]; then
        echo -e "${RED}❌ No screenshots found for $DEVICE_NAME${NC}"
        exit 1
    fi

    # Order screenshots by the manifest's human-readable names (which embed
    # the screenshot number). The exported UUID filenames alone would sort
    # randomly. `manifest_names_to_files` emits sorted `name<TAB>file` lines;
    # we take the exported file column. Use a while-read loop rather than
    # `mapfile`, which is a bash 4+ builtin absent from macOS's stock bash 3.2.
    ORDERED_EXPORTS=()
    while IFS= read -r line; do
        ORDERED_EXPORTS+=("$line")
    done < <(manifest_names_to_files "$TEMP_SCREENSHOTS/manifest.json" | cut -f2)
    if [ "${#ORDERED_EXPORTS[@]}" -eq 0 ]; then
        echo -e "${RED}❌ manifest.json contained no attachments${NC}"
        exit 1
    fi

    COUNTER=1
    for exported in "${ORDERED_EXPORTS[@]}"; do
        filename=$(printf "%s_%02d.png" "$SIZE_PREFIX" $COUNTER)
        cp "$TEMP_SCREENSHOTS/$exported" "$PRIMARY_DIR/$filename"
        echo "    ✓ $filename ($exported)"
        COUNTER=$((COUNTER + 1))
    done

    # Shut down before switching to the next device
    sim_status_bar_clear "$UDID"
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
