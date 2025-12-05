#!/bin/bash
#
# generate-appstore-screenshots.sh
# Generate App Store screenshots for all required device sizes
#
# Required sizes:
# - iPhone 6.7" (1290 x 2796) - iPhone 15 Plus
# - iPhone 6.5" (1242 x 2688) - iPhone 11 Pro Max
# - iPhone 5.5" (1242 x 2208) - iPhone 8 Plus
# - iPad Pro 12.9" (2048 x 2732)
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
# Run both App Store screenshot tests
TEST_TARGETS=(
    "WurstfingerUITests/ScreenshotTests/testGenerateAppStoreScreenshots"
    "WurstfingerUITests/ScreenshotTests/testGenerateKeyboardShowcaseScreenshots"
)
OUTPUT_DIR="$PROJECT_ROOT/appstore-screenshots"
DERIVED_DATA="/tmp/WurstfingerAppStoreScreenshots"

# Device configurations for App Store
# Format: "Device Name|Display Size|Resolution"
declare -a DEVICES=(
    "iPhone 15 Plus|6.7|1290x2796"
    "iPhone 11 Pro Max|6.5|1242x2688"
    "iPhone 8 Plus|5.5|1242x2208"
    "iPad Pro (12.9-inch) (6th generation)|12.9|2048x2732"
)

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Scheme: $SCHEME"
echo "  Output: $OUTPUT_DIR"
echo ""
echo -e "${BLUE}📱 Target Devices:${NC}"
for device_config in "${DEVICES[@]}"; do
    IFS='|' read -r name size resolution <<< "$device_config"
    echo "  - $name ($size\" - $resolution)"
done
echo ""

# Function to get device UDID
get_device_udid() {
    local device_name="$1"
    xcrun simctl list devices available | grep "$device_name" | head -n 1 | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' || true
}

# Function to run tests on a specific device
run_tests_on_device() {
    local device_name="$1"
    local display_size="$2"
    local resolution="$3"

    echo -e "${BLUE}🔄 Processing: $device_name${NC}"

    # Get device UDID
    local udid=$(get_device_udid "$device_name")

    if [ -z "$udid" ]; then
        echo -e "${YELLOW}  ⚠️  Device not available: $device_name${NC}"
        return 1
    fi

    echo "  UDID: $udid"

    # Boot simulator
    echo "  Booting simulator..."
    xcrun simctl boot "$udid" 2>/dev/null || true
    xcrun simctl bootstatus "$udid" -b 2>/dev/null || true

    # Run UI tests
    echo "  Running screenshot tests..."
    local device_derived="$DERIVED_DATA/$display_size"

    # Build the -only-testing arguments for all test targets
    local only_testing_args=""
    for target in "${TEST_TARGETS[@]}"; do
        only_testing_args="$only_testing_args -only-testing:$target"
    done

    set +e
    xcodebuild test \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$udid" \
        $only_testing_args \
        -derivedDataPath "$device_derived" \
        CODE_SIGNING_ALLOWED=NO \
        2>&1 | if command -v xcpretty >/dev/null; then xcpretty --color; else cat; fi
    local test_result=$?
    set -e

    if [ $test_result -ne 0 ]; then
        echo -e "${YELLOW}  ⚠️  Tests may have failed, checking for screenshots...${NC}"
    fi

    # Shutdown simulator
    xcrun simctl shutdown "$udid" 2>/dev/null || true

    # Extract screenshots
    local results_bundle=$(find "$device_derived" -name "*.xcresult" -type d | head -n 1)

    if [ -z "$results_bundle" ]; then
        echo -e "${RED}  ❌ No results bundle found${NC}"
        return 1
    fi

    # Create device output directory
    local device_output="$OUTPUT_DIR/${display_size}-inch"
    mkdir -p "$device_output"

    # Export attachments
    local temp_export="/tmp/appstore-screenshot-export-$display_size"
    rm -rf "$temp_export"
    xcrun xcresulttool export attachments --path "$results_bundle" --output-path "$temp_export"

    # Copy screenshots with proper names
    if [ -f "$temp_export/manifest.json" ]; then
        local count=0
        while IFS= read -r file; do
            if [[ "$file" == *.png ]]; then
                # Extract screenshot number and type from filename
                local basename=$(basename "$file")
                if [[ "$basename" == *"appstore"* ]]; then
                    # Copy to output directory
                    cp "$file" "$device_output/"
                    ((count++))
                fi
            fi
        done < <(find "$temp_export" -name "*.png" -type f)

        # Also process via manifest for proper naming
        export TEMP_EXPORT="$temp_export"
        export DEVICE_OUTPUT="$device_output"
        python3 << 'EOF'
import json
import os
import shutil

temp_export = os.environ['TEMP_EXPORT']
device_output = os.environ['DEVICE_OUTPUT']
manifest_path = os.path.join(temp_export, 'manifest.json')

if os.path.exists(manifest_path):
    with open(manifest_path, 'r') as f:
        manifest = json.load(f)

    for test_result in manifest:
        for attachment in test_result.get('attachments', []):
            exported_file = attachment['exportedFileName']
            suggested_name = attachment['suggestedHumanReadableName']

            # Skip non-image files
            if not exported_file.lower().endswith(('.png', '.jpg', '.jpeg')):
                continue

            # Only process appstore screenshots
            if 'appstore' not in suggested_name.lower():
                continue

            src_path = os.path.join(temp_export, exported_file)

            # Extract meaningful name
            # Format: appstore-device-01-keyboard-light_0_UUID.png
            parts = suggested_name.split('_')[0]
            name_parts = parts.split('-')
            if len(name_parts) >= 4:
                # Get screenshot type: 01-keyboard-light
                screenshot_type = '-'.join(name_parts[-3:])
                dest_name = f"{screenshot_type}.png"
            else:
                dest_name = f"{parts}.png"

            dest_path = os.path.join(device_output, dest_name)

            if os.path.exists(src_path):
                shutil.copy2(src_path, dest_path)
                print(f"    ✓ {dest_name}")
EOF
    fi

    # Clean up temp export
    rm -rf "$temp_export"

    echo -e "${GREEN}  ✓ Screenshots saved to $device_output${NC}"
}

# Process each device
success_count=0
for device_config in "${DEVICES[@]}"; do
    IFS='|' read -r name size resolution <<< "$device_config"
    echo ""
    if run_tests_on_device "$name" "$size" "$resolution"; then
        ((success_count++))
    fi
done

# Clean up derived data
echo ""
echo -e "${BLUE}🧹 Cleaning up...${NC}"
rm -rf "$DERIVED_DATA"

# Summary
echo ""
echo -e "${BLUE}📊 Summary:${NC}"
echo "  Processed: ${success_count}/${#DEVICES[@]} devices"
echo ""

if [ -d "$OUTPUT_DIR" ]; then
    echo -e "${BLUE}📁 Output Structure:${NC}"
    find "$OUTPUT_DIR" -type f -name "*.png" | while read -r file; do
        echo "  $file"
    done
fi

echo ""
if [ $success_count -gt 0 ]; then
    echo -e "${GREEN}✅ App Store screenshots generated successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Review screenshots in $OUTPUT_DIR"
    echo "  2. Upload to App Store Connect"
else
    echo -e "${RED}❌ No screenshots were generated${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Ensure simulators are installed for target devices"
    echo "  - Run: xcrun simctl list devices available"
    exit 1
fi

echo ""
echo -e "${GREEN}✨ Done!${NC}"
