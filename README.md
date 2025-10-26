# Wurstfinger

*The keyboard for fat fingers.*

I started this project because my favorite keyboard, MessagEase, stopped
working on iOS 26. The project is in a very early stage and currently only
implements the German layout. The goal is to build a full replacement for
MessagEase—pull requests are very welcome!

The name “Wurstfinger” is a nod to the “fat finger” problem—thumb-heavy typing on small screens.

Wurstfinger is a MessagEase-inspired keyboard for iOS written in SwiftUI. It
brings thumb-friendly gestures from Thumb-Key and the original MessagEase
layout to Apple devices, including circular gestures for uppercase letters,
return swipes for typographic punctuation, and compose rules to generate
accented characters.

## Features

- German MessagEase layout with symbol and numeric layers
- Compose engine that reproduces Thumb-Key's combination triggers (e.g. `' + a → á`)
- Return swipes for punctuation and math symbols (`?`→`¿`, `*`→`†`, `/`→`÷`, ...)
- Circular gestures on the center key to uppercase letters
- Drag gestures for cursor movement, text selection, and progressive deletion
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
xcodebuild -scheme wurstfinger -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Running Tests

The project includes unit tests for gesture handling and compose logic. Run
all tests with:

```bash
cd wurstfinger/wurstfinger
xcodebuild test -scheme wurstfinger -destination 'platform=iOS Simulator,name=iPhone 15'
```

> **Note:** Some tests require an available iOS Simulator. Adjust the
> destination to match your local simulator name if necessary.

### Installing the Keyboard

1. Build and run the `wurstfinger` scheme on a device or simulator.
2. On the device go to **Settings › General › Keyboard › Keyboards › Add New Keyboard** and select **Wurstfinger**.
3. Enable "Allow Full Access" if you want to use features that require cursor
   control and deletion shortcuts.

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
