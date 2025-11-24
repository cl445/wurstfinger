# Lower Deployment Target from iOS 18.5 to iOS 17.0

**Priority:** Critical
**Labels:** `enhancement`, `critical`, `app-store-release`

## Problem

The current deployment target is iOS 18.5, which severely limits the number of compatible devices.

## Impact

- Minimal device compatibility
- Potential users cannot install the app
- Significantly reduces App Store reach

## Current State

```
IPHONEOS_DEPLOYMENT_TARGET = 18.5
```

## Solution

Update `project.pbxproj` for all targets:

```
IPHONEOS_DEPLOYMENT_TARGET = 17.0
```

Targets to update:
- WurstfingerApp
- Wurstfinger (keyboard extension)
- WurstfingerTests
- WurstfingerUITests

## Acceptance Criteria

- [ ] All targets use iOS 17.0 as deployment target
- [ ] App builds and runs on iOS 17.0+
- [ ] No API compatibility issues
