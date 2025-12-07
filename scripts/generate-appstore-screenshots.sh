#!/bin/bash
#
# generate-appstore-screenshots.sh
# Generate App Store screenshots for all required device sizes
#
# App Store Connect required sizes:
# - iPhone 6.7" (1290 x 2796) - iPhone 14/15/16 Plus/Pro Max
# - iPhone 6.5" (1284 x 2778) - iPhone 12/13/14 Pro Max
# - iPhone 6.1" (1179 x 2556) - iPhone 14/15/16 Pro
#
# This script generates screenshots on iPhone 16 Plus and scales them
# to all required App Store dimensions.
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
TEST_TARGET="WurstfingerUITests/ScreenshotTests/testGenerateAppStoreScreenshots"
FASTLANE_SCREENSHOTS="$PROJECT_ROOT/fastlane/screenshots/en-US"
DERIVED_DATA="/tmp/WurstfingerAppStoreScreenshots"
TEMP_SCREENSHOTS="/tmp/wurstfinger-screenshots-raw"

# Source device (iPhone 16 Plus = 1290x2796)
SOURCE_DEVICE="iPhone 16 Plus"

# App Store required dimensions (width x height)
declare -A APPSTORE_SIZES=(
    ["APP_IPHONE_67"]="1290x2796"
    ["APP_IPHONE_65"]="1284x2778"
    ["APP_IPHONE_61"]="1179x2556"
)

# Create directories
mkdir -p "$FASTLANE_SCREENSHOTS"
mkdir -p "$TEMP_SCREENSHOTS"
for size_name in "${!APPSTORE_SIZES[@]}"; do
    mkdir -p "$FASTLANE_SCREENSHOTS/$size_name"
done

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Source Device: $SOURCE_DEVICE"
echo "  Output: $FASTLANE_SCREENSHOTS"
echo ""
echo -e "${BLUE}📱 Target Sizes:${NC}"
for size_name in "${!APPSTORE_SIZES[@]}"; do
    echo "  - $size_name: ${APPSTORE_SIZES[$size_name]}"
done
echo ""

# Get device UDID
get_device_udid() {
    local device_name="$1"
    xcrun simctl list devices available | grep "$device_name" | head -n 1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true
}

# Scale screenshot to target size
scale_screenshot() {
    local src="$1"
    local dst="$2"
    local target_size="$3"

    local width="${target_size%x*}"
    local height="${target_size#*x}"

    sips -z "$height" "$width" "$src" --out "$dst" > /dev/null 2>&1
}

echo -e "${BLUE}🔄 Step 1: Capture screenshots on $SOURCE_DEVICE${NC}"

UDID=$(get_device_udid "$SOURCE_DEVICE")
if [ -z "$UDID" ]; then
    echo -e "${RED}❌ Device not found: $SOURCE_DEVICE${NC}"
    echo "Available devices:"
    xcrun simctl list devices available | grep iPhone
    exit 1
fi

echo "  UDID: $UDID"

# Boot simulator
echo "  Booting simulator..."
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b 2>/dev/null || true

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

# Shutdown simulator
xcrun simctl shutdown "$UDID" 2>/dev/null || true

if [ $TEST_RESULT -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Tests may have issues, checking for screenshots...${NC}"
fi

# Find and extract screenshots from xcresult
echo ""
echo -e "${BLUE}🔄 Step 2: Extract screenshots from test results${NC}"

RESULTS_BUNDLE=$(find "$DERIVED_DATA" -name "*.xcresult" -type d | head -n 1)
if [ -z "$RESULTS_BUNDLE" ]; then
    echo -e "${RED}❌ No results bundle found${NC}"
    exit 1
fi

echo "  Results: $RESULTS_BUNDLE"

# Export attachments
rm -rf "$TEMP_SCREENSHOTS"
mkdir -p "$TEMP_SCREENSHOTS"
xcrun xcresulttool export attachments --path "$RESULTS_BUNDLE" --output-path "$TEMP_SCREENSHOTS"

# Find PNG files
PNG_COUNT=$(find "$TEMP_SCREENSHOTS" -name "*.png" -type f | wc -l | tr -d ' ')
echo "  Found $PNG_COUNT PNG files"

if [ "$PNG_COUNT" -eq 0 ]; then
    echo -e "${RED}❌ No screenshots found${NC}"
    exit 1
fi

# Process and scale screenshots
echo ""
echo -e "${BLUE}🔄 Step 3: Scale screenshots for App Store${NC}"

# Copy original 6.7" screenshots
echo "  Processing APP_IPHONE_67 (original size)..."
COUNTER=1
find "$TEMP_SCREENSHOTS" -name "*.png" -type f | sort | while read -r src; do
    filename=$(printf "%02d-screenshot.png" $COUNTER)
    cp "$src" "$FASTLANE_SCREENSHOTS/APP_IPHONE_67/$filename"
    echo "    ✓ $filename"
    COUNTER=$((COUNTER + 1))
done

# Scale to other sizes
for size_name in "APP_IPHONE_65" "APP_IPHONE_61"; do
    target_size="${APPSTORE_SIZES[$size_name]}"
    echo "  Processing $size_name ($target_size)..."

    COUNTER=1
    for src in "$FASTLANE_SCREENSHOTS/APP_IPHONE_67"/*.png; do
        if [ -f "$src" ]; then
            filename=$(printf "%02d-screenshot.png" $COUNTER)
            scale_screenshot "$src" "$FASTLANE_SCREENSHOTS/$size_name/$filename" "$target_size"
            echo "    ✓ $filename"
            COUNTER=$((COUNTER + 1))
        fi
    done
done

# Cleanup
echo ""
echo -e "${BLUE}🧹 Cleaning up...${NC}"
rm -rf "$DERIVED_DATA"
rm -rf "$TEMP_SCREENSHOTS"

# Summary
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
for size_name in "${!APPSTORE_SIZES[@]}"; do
    count=$(find "$FASTLANE_SCREENSHOTS/$size_name" -name "*.png" -type f | wc -l | tr -d ' ')
    echo "  $size_name: $count screenshots"
done

echo ""
echo -e "${GREEN}✅ App Store screenshots generated successfully!${NC}"
echo ""
echo -e "${BLUE}📁 Output:${NC}"
echo "  $FASTLANE_SCREENSHOTS"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "  1. Review screenshots"
echo "  2. Commit and push"
echo "  3. Run fastlane release"
echo ""
echo -e "${GREEN}✨ Done!${NC}"
