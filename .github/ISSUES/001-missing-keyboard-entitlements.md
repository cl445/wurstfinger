# Missing Keyboard Extension Entitlements File

**Priority:** Critical
**Labels:** `bug`, `critical`, `app-store-release`

## Problem

The project references a non-existent entitlements file for the keyboard extension:
- Referenced path: `Wurstfinger/Wurstfinger.entitlements`
- File does not exist

## Impact

- Build failure when compiling
- App cannot be code signed
- Blocks App Store submission

## Solution

Create the entitlements file with the required App Group:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.de.akator.wurstfinger.shared</string>
    </array>
</dict>
</plist>
```

## Acceptance Criteria

- [ ] Entitlements file exists at correct path
- [ ] App Group configured correctly
- [ ] Project builds successfully
