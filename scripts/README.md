# Screenshot Generation

This directory contains scripts for automated screenshot generation.

## generate-screenshots.sh

Automatically generates screenshots of the keyboard for documentation purposes.

### Usage

```bash
cd wurstfinger/wurstfinger
./scripts/generate-screenshots.sh
```

The `ScreenshotTests` skip themselves unless the test runner sees
`GENERATE_SCREENSHOTS=1`, so a plain `xcodebuild test` does not pay for ~15 app
relaunches. The script passes it as `TEST_RUNNER_GENERATE_SCREENSHOTS=1`; add
the same setting when invoking `xcodebuild` by hand.

### What it does

1. Runs UI tests (`ScreenshotTests`) that capture the keyboard in different states
2. Uses English keyboard layout for consistency
3. Automatically crops screenshots to keyboard area only
4. Converts screenshots to WebP format for optimal file size
5. Exports screenshots to `docs/images/`
6. Screenshots are captured for:
   - Lower case layout (light & dark theme)
   - Numbers layer (light & dark theme)

### Requirements

- Xcode 16+
- An available iPhone simulator (the script picks the first non-SE iPhone it finds)
- `xcpretty` gem (install with `gem install xcpretty`)
- Python 3 with Pillow and NumPy (install with `pip3 install Pillow numpy`)

### Output

Screenshots are saved to `../docs/images/` as WebP files:

- `keyboard-lower-light.webp` - Lower case layout (light theme)
- `keyboard-lower-dark.webp` - Lower case layout (dark theme)
- `keyboard-numbers-light.webp` - Numbers layer (light theme)
- `keyboard-numbers-dark.webp` - Numbers layer (dark theme)

All screenshots are automatically cropped to show only the keyboard area.

## Implementation Details

The screenshot system consists of:

1. **KeyboardShowcaseView.swift** - Special view that displays the keyboard with minimal spacing
2. **ScreenshotTests.swift** - UI tests that capture screenshots in different states
3. **wurstfingerApp.swift** - Launch argument support for screenshot mode
4. **generate-screenshots.sh** - Script that orchestrates everything and converts to WebP

The app enters "screenshot mode" when launched with the `SCREENSHOT_MODE` argument, which displays a minimal keyboard preview. Environment variables control the appearance:

- `FORCE_LANGUAGE` - Sets keyboard language (e.g., "en_US")
- `FORCE_LAYER` - Sets keyboard layer ("lower", "upper", "numbers", "symbols")
- `FORCE_APPEARANCE` - Sets theme ("light", "dark")
