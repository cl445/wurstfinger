# Create Privacy Manifest (PrivacyInfo.xcprivacy)

**Priority:** Critical
**Labels:** `bug`, `critical`, `app-store-release`

## Problem

Since iOS 17, a Privacy Manifest is required for App Store submissions. This file is missing from the project.

## Impact

- App rejection during App Store Review
- Blocks App Store submission

## Solution

Create `PrivacyInfo.xcprivacy` file in the main app target:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array/>
</dict>
</plist>
```

## Reference

- [Apple Documentation: Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)

## Acceptance Criteria

- [ ] PrivacyInfo.xcprivacy exists in main app bundle
- [ ] Privacy manifest declares no data collection (as per app's privacy statement)
- [ ] File is included in Xcode project
