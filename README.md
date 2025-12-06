# Wurstfinger

*The keyboard for fat fingers.*

The name “Wurstfinger” is a nod to the “fat finger” problem—thumb-heavy typing on small screens.

Wurstfinger is a MessagEase-inspired keyboard for iOS written in SwiftUI. It
brings thumb-friendly gestures from Thumb-Key and the original MessagEase
layout to Apple devices, including circular gestures for uppercase letters,
return swipes for typographic punctuation, and compose rules to generate
accented characters.

## Join the Beta

Want to try Wurstfinger before the official release? Join our public TestFlight beta!

[![Join TestFlight Beta](https://img.shields.io/badge/TestFlight-Join%20Beta-blue?logo=apple&logoColor=white)](https://testflight.apple.com/join/trX4rBPf)

**Beta Features:**
- Nightly builds with the latest features from the `develop` branch
- Help shape the keyboard with your feedback
- Early access to experimental features

**Requirements:**
- iOS 17.0 or later
- TestFlight app ([free download from App Store](https://apps.apple.com/app/testflight/id899247664))

**Note:** Beta builds are automatically generated every night at 2 AM UTC when there are new changes. The first build after joining may take 1-2 hours for Apple's beta review process.

## Preview

<table>
  <tr>
    <td width="50%">
      <img src="docs/images/keyboard-lower-light.webp" alt="Lower case layout (light)" width="100%">
      <p align="center"><i>Light Theme</i></p>
    </td>
    <td width="50%">
      <img src="docs/images/keyboard-lower-dark.webp" alt="Lower case layout (dark)" width="100%">
      <p align="center"><i>Dark Theme</i></p>
    </td>
  </tr>
  <tr>
    <td width="50%">
      <img src="docs/images/keyboard-numbers-light.webp" alt="Numbers layout (light)" width="100%">
      <p align="center"><i>Numbers Layer</i></p>
    </td>
    <td width="50%">
      <img src="docs/images/keyboard-numbers-dark.webp" alt="Numbers layout (dark)" width="100%">
      <p align="center"><i>Numbers Layer (Dark)</i></p>
    </td>
  </tr>
</table>

## Features

- **Multi-language support**: 14 languages including English, German, Spanish, French, Portuguese, Italian, Dutch, Swedish, Norwegian, Danish, Finnish, Polish, Czech, and Vietnamese
- **MessagEase layout** with symbol and numeric layers
- **Compose engine** that reproduces Thumb-Key's combination triggers (e.g. `' + a → á`)
- **Return swipes** for punctuation and math symbols (`?`→`¿`, `*`→`†`, `/`→`÷`, ...)
- **Circular gestures** on keys to insert uppercase letters
- **Drag gestures** for cursor movement and progressive deletion
- **Customizable settings**: Adjust haptic feedback intensity, keyboard scale, and key aspect ratio
- **Onboarding flow** with interactive setup guide
- Support for iOS 17+ (Swift 5, SwiftUI)

## Getting Started

### Prerequisites

- Xcode 16 (or newer)
- iOS 17 SDK

### Building

Open the project in Xcode:

```bash
xed wurstfinger/wurstfinger.xcodeproj
```

or build from the command line on macOS:

```bash
cd wurstfinger/wurstfinger
xcodebuild -scheme Wurstfinger -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### Running Tests

The project includes unit tests for gesture handling and compose logic. Run
all tests with:

```bash
cd wurstfinger/wurstfinger
xcodebuild test -scheme Wurstfinger -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WurstfingerTests
```

> **Note:** Some tests require an available iOS Simulator. Adjust the
> destination to match your local simulator name if necessary.

### Installing the Keyboard

1. Build and run the `Wurstfinger` scheme on a device or simulator.
2. The app includes an interactive onboarding guide that walks you through:
   - Adding the keyboard in **Settings › General › Keyboard › Keyboards**
   - Enabling "Allow Full Access" for cursor control and deletion features
   - Testing the keyboard in the practice view

### Project Layout

```
wurstfinger/
├─ README.md
├─ LICENSE
├─ wurstfinger/                # Xcode project root
│  ├─ wurstfinger.xcodeproj    # Project file
│  ├─ wurstfinger/             # Host app (minimal)
│  ├─ wurstfingerKeyboard/     # Keyboard extension sources
│  ├─ wurstfingerTests/        # Swift Testing unit tests
│  └─ wurstfingerUITests/      # UI test target (currently empty)
```

## License

This project is licensed under the [MIT License](LICENSE).

## Acknowledgements

- [MessagEase](https://www.exideas.com/) for the original layout concepts
- [Thumb-Key](https://github.com/dessalines/thumb-key) for inspiration and
  compose rules
