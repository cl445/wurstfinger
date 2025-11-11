# Screenshot Generation

This directory contains scripts for automated screenshot generation.

## generate-screenshots.sh

Automatically generates screenshots of the keyboard for documentation purposes.

### Usage

```bash
cd wurstfinger/wurstfinger
./scripts/generate-screenshots.sh
```

### What it does

1. Runs UI tests (`ScreenshotTests`) that capture the keyboard in different states
2. Uses English keyboard layout for consistency
3. Exports screenshots to `docs/images/`
4. Screenshots are captured in the following states:
   - Lower case layout
   - Numbers layer
   - Main showcase view (for README)

### Requirements

- Xcode 16+
- iPhone 16 simulator installed
- `xcpretty` gem (install with `gem install xcpretty`)

### Output

Screenshots are saved to `../docs/images/` with names:
- `demo-showcase.png` - Main keyboard view for README
- `keyboard-lower.png` - Lower case layout
- `keyboard-numbers.png` - Numbers layer

### Converting to WebP

For better compression in the README:

```bash
cd ../docs/images
sips -s format webp demo-showcase.png --out demo-showcase.webp
```

## Implementation Details

The screenshot system consists of:

1. **KeyboardShowcaseView.swift** - Special view that displays the keyboard without text input
2. **ScreenshotTests.swift** - UI tests that capture screenshots
3. **wurstfingerApp.swift** - Launch argument support for screenshot mode
4. **generate-screenshots.sh** - Script that orchestrates everything

The app enters "screenshot mode" when launched with the `SCREENSHOT_MODE` argument, which displays only the keyboard preview. The language can be forced using the `FORCE_LANGUAGE` environment variable.
