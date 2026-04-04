# Release Checklist

## Before the release

- [ ] All relevant PRs merged into `develop`
- [ ] CI green on `develop`
- [ ] Update `fastlane/metadata/de-DE/release_notes.txt`
- [ ] Update `fastlane/metadata/en-US/release_notes.txt`
- [ ] Update `CHANGELOG.md` — rename "Unreleased" to `v X.Y.Z — YYYY-MM-DD`, add empty "Unreleased" section
- [ ] Bump `MARKETING_VERSION` in `Wurstfinger.xcodeproj/project.pbxproj` (all targets)
- [ ] Verify version bump: `grep MARKETING_VERSION Wurstfinger.xcodeproj/project.pbxproj`
- [ ] Commit: `Bump version to X.Y.Z`
- [ ] Push `develop`

## Create the release

- [ ] Merge `develop` → `main`: `git checkout main && git merge develop --no-edit`
- [ ] Push `main`
- [ ] Tag: `git tag vX.Y.Z && git push origin vX.Y.Z`
- [ ] Create GitHub release: `gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."`
- [ ] Verify `vX.Y.Z` is marked as "Latest": `gh release list --limit 3`
  - If not: `gh release edit vX.Y.Z --latest`

## After the release

- [ ] Verify App Store Release workflow succeeds: `gh run list --workflow="App Store Release" --limit 3`
- [ ] Check App Store Connect: correct version, release notes, and build
- [ ] Switch back to `develop`: `git checkout develop`

## Troubleshooting

### Fastlane fails with "version number has been previously used"
The `MARKETING_VERSION` bump is missing from the Xcode project. Verify with:
```bash
grep MARKETING_VERSION Wurstfinger.xcodeproj/project.pbxproj
```
Fix, commit, force-update the tag, and re-trigger the workflow.

### App Store Connect asks to "select a build"
Fastlane's `upload_to_app_store` needs the `build_number` parameter to attach the uploaded build to the version. Without it, the version is created but no build is selected. This is already configured in the Fastfile — if it happens anyway, check that `get_build_number` returns the correct value.

### Build shows "missing compliance" in App Store Connect
The `ITSAppUsesNonExemptEncryption` flag must be set in both the host app and the keyboard extension. The host app uses `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` in the Xcode build settings (no separate Info.plist). The keyboard extension is set via Fastlane in the Fastfile.

### Wrong release notes in App Store Connect
Fastlane reads from `fastlane/metadata/*/release_notes.txt`. Update them before creating the release. If already submitted, edit directly in App Store Connect or re-run the workflow after fixing.

### Wrong release marked as "Latest" on GitHub
```bash
gh release edit vX.Y.Z --latest
```
