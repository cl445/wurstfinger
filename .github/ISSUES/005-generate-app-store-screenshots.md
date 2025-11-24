# Generate App Store Screenshots

**Priority:** High
**Labels:** `enhancement`, `app-store-release`

## Problem

App Store screenshots in various device sizes are required for submission.

## Required Screenshot Sizes

| Device | Size (pixels) | Required |
|--------|---------------|----------|
| iPhone 6.7" | 1290 x 2796 | Yes |
| iPhone 6.5" | 1242 x 2688 | Yes |
| iPhone 5.5" | 1242 x 2208 | Optional |
| iPad Pro 12.9" (6th gen) | 2048 x 2732 | Yes (if iPad supported) |

## Existing Infrastructure

The project already has screenshot generation infrastructure:

- `WurstfingerUITests/ScreenshotTests.swift` - UI test for capturing screenshots
- `scripts/generate-screenshots.sh` - Automation script
- `.github/workflows/update-screenshots.yml` - CI workflow
- `KeyboardShowcaseView.swift` - Special screenshot mode

### Environment Variables

```bash
FORCE_LANGUAGE=de|en
FORCE_LAYER=lower|upper|numbers|special
FORCE_APPEARANCE=light|dark
```

## Tasks

- [ ] Generate screenshots for all required device sizes
- [ ] Create light and dark mode variants
- [ ] Generate for both German and English locales
- [ ] Organize in `fastlane/screenshots/` directory
- [ ] Update fastlane to upload screenshots

## Directory Structure

```
fastlane/screenshots/
├── de-DE/
│   ├── iPhone 6.7" Display/
│   ├── iPhone 6.5" Display/
│   └── iPad Pro 12.9"/
└── en-US/
    ├── iPhone 6.7" Display/
    ├── iPhone 6.5" Display/
    └── iPad Pro 12.9"/
```

## Acceptance Criteria

- [ ] All required device sizes covered
- [ ] Both light and dark mode screenshots
- [ ] German and English localizations
- [ ] Screenshots uploaded via fastlane
