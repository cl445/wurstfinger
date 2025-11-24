# Configure App Store Metadata in Fastlane

**Priority:** High
**Labels:** `enhancement`, `app-store-release`

## Problem

App Store metadata (description, keywords, etc.) is not configured for the release.

## Tasks

Create `fastlane/metadata/` directory structure with localized content:

### German (de-DE)
- [ ] `fastlane/metadata/de-DE/name.txt` - App name
- [ ] `fastlane/metadata/de-DE/subtitle.txt` - App subtitle
- [ ] `fastlane/metadata/de-DE/description.txt` - Full app description
- [ ] `fastlane/metadata/de-DE/keywords.txt` - Search keywords (comma-separated)
- [ ] `fastlane/metadata/de-DE/promotional_text.txt` - Promotional text
- [ ] `fastlane/metadata/de-DE/release_notes.txt` - Release notes

### English (en-US)
- [ ] `fastlane/metadata/en-US/name.txt` - App name
- [ ] `fastlane/metadata/en-US/subtitle.txt` - App subtitle
- [ ] `fastlane/metadata/en-US/description.txt` - Full app description
- [ ] `fastlane/metadata/en-US/keywords.txt` - Search keywords (comma-separated)
- [ ] `fastlane/metadata/en-US/promotional_text.txt` - Promotional text
- [ ] `fastlane/metadata/en-US/release_notes.txt` - Release notes

### Common Files
- [ ] `fastlane/metadata/privacy_url.txt` - Privacy policy URL
- [ ] `fastlane/metadata/support_url.txt` - Support URL
- [ ] `fastlane/metadata/primary_category.txt` - App Store category

## Suggested Content

**Keywords (de-DE):**
```
Tastatur,Keyboard,Deutsch,German,iOS,Wurstfinger,Tippen,Schreiben
```

**Keywords (en-US):**
```
Keyboard,German,iOS,Wurstfinger,Typing,Custom,Extension
```

## Acceptance Criteria

- [ ] Metadata directory structure created
- [ ] German localization complete
- [ ] English localization complete
- [ ] Privacy and support URLs configured
