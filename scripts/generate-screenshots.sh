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
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.6"
TEST_TARGET="WurstfingerUITests/ScreenshotTests"
DOCS_DIR="$PROJECT_ROOT/../docs/images"
DERIVED_DATA="/tmp/WurstfingerScreenshots"

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_DIR"

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Scheme: $SCHEME"
echo "  Destination: $DESTINATION"
echo "  Output: $DOCS_DIR"
echo ""

# Run UI tests to generate screenshots
echo -e "${BLUE}🧪 Running UI tests to generate screenshots...${NC}"
xcodebuild test \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -only-testing:"$TEST_TARGET" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  | xcpretty --color || true

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
    # Parse manifest and copy files with proper names
    export TEMP_EXPORT
    export DOCS_DIR
    python3 << 'EOF'
import json
import shutil
import os

manifest_path = os.environ['TEMP_EXPORT'] + '/manifest.json'
docs_dir = os.environ['DOCS_DIR']

with open(manifest_path, 'r') as f:
    manifest = json.load(f)

for test_result in manifest:
    for attachment in test_result.get('attachments', []):
        exported_file = attachment['exportedFileName']
        suggested_name = attachment['suggestedHumanReadableName']

        # Extract base name (e.g., "keyboard-lower" from "keyboard-lower_0_UUID.png")
        base_name = suggested_name.split('_')[0]

        src_path = os.path.join(os.environ['TEMP_EXPORT'], exported_file)
        dst_path = os.path.join(docs_dir, f'{base_name}.png')

        if os.path.exists(src_path):
            shutil.copy2(src_path, dst_path)
            print(f"  ✓ Copied {base_name}.png")
EOF

    # Count copied files
    COPIED=$(ls -1 "$DOCS_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ')
fi

# Clean up temp export
rm -rf "$TEMP_EXPORT"

echo ""
if [ $COPIED -gt 0 ]; then
  echo -e "${GREEN}✅ Success! Copied $COPIED screenshot(s) to $DOCS_DIR${NC}"
  echo ""
  echo -e "${BLUE}📝 Next steps:${NC}"
  echo "  1. Review screenshots in: $DOCS_DIR"
  echo "  2. Rename screenshots if needed:"
  echo "     - demo-showcase.png (main README image)"
  echo "     - keyboard-lower.png"
  echo "     - keyboard-numbers.png"
  echo "  3. Convert to WebP for better compression:"
  echo "     sips -s format webp demo-showcase.png --out demo-showcase.webp"
else
  echo -e "${RED}❌ No screenshots found${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  - Check if UI tests ran successfully"
  echo "  - Verify simulator is available"
  echo "  - Run tests manually: xcodebuild test -scheme $SCHEME -destination '$DESTINATION' -only-testing:$TEST_TARGET"
fi

echo ""
echo -e "${BLUE}🧹 Cleaning up...${NC}"
rm -rf "$DERIVED_DATA"
rm -f /tmp/test-results.json

echo -e "${GREEN}✨ Done!${NC}"
