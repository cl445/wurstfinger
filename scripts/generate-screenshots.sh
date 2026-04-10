#!/bin/bash
#
# generate-screenshots.sh
# Automatically generate screenshots for documentation
#
# Usage: ./scripts/generate-screenshots.sh

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🖼️  Wurstfinger Screenshot Generator${NC}"
echo ""

# Change to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Configuration
SCHEME="Wurstfinger"
# Detect available iPhone simulator
DEVICE_NAME=$(xcrun simctl list devices available | grep "iPhone" | grep -v "SE" | head -n 1 | sed 's/    //g' | sed 's/ (.*//g' | xargs)

if [ -z "$DEVICE_NAME" ]; then
    DEVICE_NAME="iPhone 16"
    echo "⚠️  Could not detect available simulator, falling back to $DEVICE_NAME"
else
    echo "📱 Detected simulator: $DEVICE_NAME"
fi

DESTINATION="platform=iOS Simulator,name=$DEVICE_NAME"
TEST_TARGET="WurstfingerUITests/ScreenshotTests"
DOCS_DIR="$PROJECT_ROOT/docs/images"
DERIVED_DATA="/tmp/WurstfingerScreenshots"

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_DIR"

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Scheme: $SCHEME"
echo "  Destination: $DESTINATION"
echo "  Output: $DOCS_DIR"
echo ""

# Find target simulator UDID by name
TARGET_UDID=$(xcrun simctl list devices available -j | python3 -c "
import json, sys
name = '$DEVICE_NAME'
devices = json.load(sys.stdin)['devices']
for runtime_devices in devices.values():
    for d in runtime_devices:
        if d.get('name') == name and d.get('isAvailable', True):
            print(d['udid'])
            raise SystemExit(0)
raise SystemExit(1)
" 2>/dev/null || true)

# Ensure cleanup runs on any exit (normal, error, or signal)
cleanup() {
    echo ""
    echo -e "${BLUE}🧹 Cleaning up...${NC}"
    if [ -n "$TARGET_UDID" ]; then
        xcrun simctl status_bar "$TARGET_UDID" clear 2>/dev/null || true
    fi
    rm -rf "$DERIVED_DATA"
}
trap cleanup EXIT

# Override status bar to get consistent screenshots (Apple's standard 9:41)
echo -e "${BLUE}⏰ Setting consistent status bar...${NC}"
if [ -n "$TARGET_UDID" ]; then
    xcrun simctl status_bar "$TARGET_UDID" override --time "9:41" --batteryState charged --batteryLevel 100
    echo "  Set status bar to 9:41 on $TARGET_UDID ($DEVICE_NAME)"
else
    echo "  ⚠️  Could not find simulator '$DEVICE_NAME', skipping status bar override"
fi
echo ""

# Run UI tests to generate screenshots
echo -e "${BLUE}🧪 Running UI tests to generate screenshots...${NC}"

# Debug: Show simulator status
echo -e "${BLUE}📱 Simulator status before test:${NC}"
xcrun simctl list devices booted || echo "No booted devices"
echo ""

TEST_OUTPUT=$(mktemp)
set +e
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"$TEST_TARGET" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$TEST_OUTPUT" | if command -v xcpretty >/dev/null; then xcpretty --color; else cat; fi
TEST_EXIT_CODE=${PIPESTATUS[0]}
set -e

if [ $TEST_EXIT_CODE -ne 0 ]; then
  echo -e "${RED}⚠️  UI tests failed (exit code: $TEST_EXIT_CODE), but continuing to check for screenshots...${NC}"
fi

echo ""
echo -e "${BLUE}📤 Exporting screenshots...${NC}"

# Find the test results bundle
RESULTS_BUNDLE=$(find "$DERIVED_DATA" -name "*.xcresult" -type d | head -n 1)

if [ -z "$RESULTS_BUNDLE" ]; then
  echo -e "${RED}❌ Error: Could not find test results bundle${NC}"
  exit 1
fi

echo "  Results bundle: $RESULTS_BUNDLE"

# Extract screenshots using xcresulttool export attachments
echo ""
echo -e "${BLUE}🔍 Extracting screenshots with proper names...${NC}"

# Export all attachments
TEMP_EXPORT="/tmp/screenshot-exports"
rm -rf "$TEMP_EXPORT"
xcrun xcresulttool export attachments --path "$RESULTS_BUNDLE" --output-path "$TEMP_EXPORT"

# Map exported files to proper names based on manifest
if [ -f "$TEMP_EXPORT/manifest.json" ]; then
    # Parse manifest, crop, and convert to WebP
    export TEMP_EXPORT
    export DOCS_DIR
    python3 << 'EOF'
import json
import os
import re
import numpy as np
from PIL import Image

manifest_path = os.environ['TEMP_EXPORT'] + '/manifest.json'
docs_dir = os.environ['DOCS_DIR']

# Screenshots that come from the tab-based app (Home/Test/Settings/Setup) —
# these include the system status bar (clock!) and the home indicator. We
# strip fixed top/bottom bands so the current clock time cannot introduce
# spurious pixel diffs. Ratios are derived from iPhone 16/17 Pro (2622px
# tall at 3x) but scale with image height so other simulators crop sanely
# too. The status bar ratio includes safety margin for the Dynamic Island.
TAB_SCREEN_RE = re.compile(r'-0[1-5]-(home|test-light|test-dark|settings|setup)$')
STATUS_BAR_RATIO = 210 / 2622
HOME_INDICATOR_RATIO = 80 / 2622

# Screenshots that come from AppStoreScreenshotView (chat + keyboard). These
# fill the whole screen and have no visible system status bar, so they must
# not be cropped — doing so would chop off the chat header.
APPSTORE_CHAT_RE = re.compile(r'-keyboard-0[1-4]-')


def find_runs(mask):
    diffs = np.diff(mask.astype(np.int8))
    starts = (np.where(diffs == 1)[0] + 1).tolist()
    ends = (np.where(diffs == -1)[0] + 1).tolist()
    if mask[0]:
        starts.insert(0, 0)
    if mask[-1]:
        ends.append(len(mask))
    return list(zip(starts, ends))


def merge_close_runs(runs, gap):
    if not runs:
        return []
    merged = [runs[0]]
    for start, end in runs[1:]:
        prev_start, prev_end = merged[-1]
        if start - prev_end <= gap:
            merged[-1] = (prev_start, end)
        else:
            merged.append((start, end))
    return merged


def largest_content_block_crop(img, threshold=10, gap=100, padding=10):
    """Crop to the largest contiguous block of non-background content.

    Unlike a naive first-to-last variance crop, this merges nearby runs and
    picks the single largest block. This reliably isolates the keyboard grid
    and ignores the iOS home indicator (a tiny, far-away run) that would
    otherwise extend the crop across the entire screen.
    """
    arr = np.array(img)
    gray = np.mean(arr, axis=2)
    row_var = np.var(gray, axis=1)
    col_var = np.var(gray, axis=0)

    row_runs = merge_close_runs(find_runs(row_var > threshold), gap)
    col_runs = merge_close_runs(find_runs(col_var > threshold), gap)
    if not row_runs or not col_runs:
        return img

    top, bottom = max(row_runs, key=lambda r: r[1] - r[0])
    left, right = max(col_runs, key=lambda r: r[1] - r[0])

    top = max(0, top - padding)
    bottom = min(img.height, bottom + padding)
    left = max(0, left - padding)
    right = min(img.width, right + padding)
    return img.crop((left, top, right, bottom))


def crop_screenshot(img, base_name):
    if TAB_SCREEN_RE.search(base_name):
        # Proportional crop: strip status bar + home indicator.
        top = min(int(round(img.height * STATUS_BAR_RATIO)), img.height)
        bottom = max(top, img.height - int(round(img.height * HOME_INDICATOR_RATIO)))
        return img.crop((0, top, img.width, bottom))
    if APPSTORE_CHAT_RE.search(base_name):
        # AppStoreScreenshotView already fills the screen exactly.
        return img
    # Keyboard-only showcase: isolate the dense keyboard block.
    return largest_content_block_crop(img)


with open(manifest_path, 'r') as f:
    manifest = json.load(f)

for test_result in manifest:
    for attachment in test_result.get('attachments', []):
        exported_file = attachment['exportedFileName']
        suggested_name = attachment['suggestedHumanReadableName']

        # Skip non-image files (videos, etc.)
        if not exported_file.lower().endswith(('.png', '.jpg', '.jpeg')):
            print(f"  ⏭ Skipping non-image: {exported_file}")
            continue

        # Extract base name (e.g., "keyboard-lower-light" from "keyboard-lower-light_0_UUID.png")
        base_name = suggested_name.split('_')[0]

        src_path = os.path.join(os.environ['TEMP_EXPORT'], exported_file)
        temp_png = os.path.join(os.environ['TEMP_EXPORT'], f'{base_name}-temp.png')
        final_webp = os.path.join(docs_dir, f'{base_name}.webp')

        if os.path.exists(src_path):
            img = Image.open(src_path)

            # Convert to RGB if necessary
            if img.mode in ('RGBA', 'LA', 'P'):
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'P':
                    img = img.convert('RGBA')
                background.paste(img, mask=img.split()[-1] if img.mode == 'RGBA' else None)
                img = background

            img = crop_screenshot(img, base_name)

            # Save as WebP with good quality
            img.save(final_webp, 'WEBP', quality=85)
            print(f"  ✓ Created {base_name}.webp ({img.width}x{img.height})")
EOF

    # Count created files
    COPIED=$(ls -1 "$DOCS_DIR"/*.webp 2>/dev/null | wc -l | tr -d ' ')
fi

# Clean up temp export
rm -rf "$TEMP_EXPORT"

echo ""
if [ $COPIED -gt 0 ]; then
  echo -e "${GREEN}✅ Success! Created $COPIED WebP screenshot(s) in $DOCS_DIR${NC}"
  echo ""
  echo -e "${BLUE}📝 Generated screenshots:${NC}"
  echo "    - keyboard-lower-light.webp"
  echo "    - keyboard-lower-dark.webp"
  echo "    - keyboard-numbers-light.webp"
  echo "    - keyboard-numbers-dark.webp"
else
  echo -e "${RED}❌ No screenshots found${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  - Check if UI tests ran successfully"
  echo "  - Verify simulator is available"
  echo "  - Verify Pillow is installed: pip3 install Pillow"
  echo "  - Run tests manually: xcodebuild test -scheme $SCHEME -destination '$DESTINATION' -only-testing:$TEST_TARGET"
fi

echo -e "${GREEN}✨ Done!${NC}"
