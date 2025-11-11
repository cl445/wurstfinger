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
DESTINATION="platform=iOS Simulator,name=iPhone 16"
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

# Export screenshots using xcresulttool
ATTACHMENTS_DIR=$(find "$RESULTS_BUNDLE" -name "Attachments" -type d | head -n 1)

if [ -z "$ATTACHMENTS_DIR" ]; then
  echo -e "${RED}❌ Error: Could not find attachments directory${NC}"
  exit 1
fi

echo "  Attachments dir: $ATTACHMENTS_DIR"

# Copy screenshots to docs folder
COPIED=0
for screenshot in "$ATTACHMENTS_DIR"/*.png; do
  if [ -f "$screenshot" ]; then
    BASENAME=$(basename "$screenshot")
    # Screenshots are named with hash, we need to match them to our names
    # For now, copy all and let user rename or use xcrun xcresulttool
    cp "$screenshot" "$DOCS_DIR/"
    COPIED=$((COPIED + 1))
  fi
done

# Try to extract with proper names using xcresulttool
echo ""
echo -e "${BLUE}🔍 Extracting named screenshots...${NC}"

# Get screenshot IDs and names
xcrun xcresulttool get --path "$RESULTS_BUNDLE" --format json > /tmp/test-results.json

# Extract attachments with proper names (this is complex, for now we'll use a simpler approach)
# List all attachments
xcrun xcresulttool get attachments --path "$RESULTS_BUNDLE" 2>/dev/null || true

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
