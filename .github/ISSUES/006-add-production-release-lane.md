# Add Production Release Lane to Fastlane

**Priority:** High
**Labels:** `enhancement`, `app-store-release`

## Problem

Currently only a `beta` lane exists for TestFlight distribution. A production release lane is needed for App Store submission.

## Current State

`fastlane/Fastfile` only contains:
- `beta` lane - Uploads to TestFlight

## Solution

Add a `release` lane to Fastfile:

```ruby
lane :release do
  # Ensure we're on a clean state
  ensure_git_status_clean

  # Build the app
  build_app(
    scheme: "WurstfingerApp",
    export_method: "app-store",
    clean: true
  )

  # Upload metadata and screenshots
  upload_to_app_store(
    skip_binary_upload: false,
    skip_screenshots: false,
    skip_metadata: false,
    submit_for_review: false,
    automatic_release: false,
    force: true
  )
end
```

## Tasks

- [ ] Create `release` lane in Fastfile
- [ ] Configure App Store Connect API authentication
- [ ] Add metadata upload step
- [ ] Add screenshot upload step
- [ ] Configure submission options
- [ ] Add GitHub Actions workflow for releases (optional)

## Acceptance Criteria

- [ ] `fastlane release` successfully builds app
- [ ] Metadata is uploaded to App Store Connect
- [ ] Screenshots are uploaded to App Store Connect
- [ ] App is ready for manual review submission
