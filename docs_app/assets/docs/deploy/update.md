# `flow deploy update`

Build and submit an app update to the stores. iOS goes through App Store
Connect; Android goes through Google Play. Always uses the `fastlane`
provider — Firebase App Distribution doesn't ship public updates.

## Synopsis

```bash
flow deploy update [--platform <ios|android>]
                   [--flavor <name>] [--target <path>]
                   [--skip-build] [--increment-version | --skip-version-increment]
```

## Options

Same option set as [`flow deploy beta`](/deploy/beta), with one
restriction: `--provider` is implicit (`fastlane`). Passing
`--provider firebase` here will fail validation.

## Pipeline

For each platform you target:

1. Build a release artifact (`.aab` for Android, `.ipa` for iOS).
2. Bump the version (unless `skip_version_increment` overrides).
3. Run the appropriate Fastlane lane:
   - **Android**: `supply` action → Google Play production track.
   - **iOS**: `deliver` action → App Store Connect → submit for review →
     `automatic_release: true` so the build goes live on approval.

Localized changelogs from `android.changelog` / `ios.changelog` are
attached to the submission.

## Walkthrough — production update on both platforms

```terminal
$ flow deploy update
✓ Loaded .flow_deploy.json
ℹ Deployment provider: fastlane
ℹ Platform: all
ℹ Build flavor: production

→ flutter build appbundle --release --flavor production …
✓ Built build/app/outputs/bundle/productionRelease/app-production-release.aab (24.6MB)

→ flutter build ipa --release --flavor production …
✓ Built build/ios/ipa/Acme.ipa (52.8MB)

→ flow deploy version --patch
ℹ pubspec.yaml: 1.4.0+87 → 1.4.1+88

→ fastlane android new_update
  → supply: uploading to track 'production'…
  ✓ Build 88 uploaded to Google Play
  ✓ Listing updated (en-US, ar-SA, fr-FR)

→ fastlane ios new_update
  → deliver: uploading to App Store Connect…
  ✓ Build 88 submitted for App Review
  ✓ automatic_release: true — release on approval

Done.
ℹ Apple typically reviews within 24-48 hours.
ℹ Google Play processing usually completes within a few hours.
```

## Walkthrough — Android only

```terminal
$ flow deploy update -p android
✓ Loaded .flow_deploy.json
…
→ fastlane android new_update
  ✓ Build 88 uploaded to Google Play
  ✓ Release moved to "Production" track
Done.
```

## Walkthrough — iOS only, with an explicit version bump

```terminal
$ flow deploy update -p ios --increment-version
ℹ Bumping version before build
ℹ pubspec.yaml: 1.4.0+87 → 1.4.1+88
…
→ fastlane ios new_update
  ✓ Build 88 submitted for App Review
Done.
```

## What gets submitted (iOS)

The fastlane `deliver` action sends:

- The `.ipa` artifact.
- `ios.changelog` → App Store Connect "What's New in This Version" per
  locale.
- The current pubspec version (which becomes the version on the listing).
- `submit_for_review: true` — moves the build directly into App Review.
- `automatic_release: true` — auto-publishes on approval.

The submission includes export compliance defaults (no non-standard
encryption, no IDFA, no third-party content). These match the generated
`ios/fastlane/Fastfile`. If your app uses different cryptography or IDFA,
edit `ios/fastlane/Fastfile` to override the `submission_information` block.

## What gets submitted (Android)

The fastlane `supply` action sends:

- The `.aab` artifact.
- `android.changelog` per locale.
- A new release on the **production** track (the default for `supply`).

To target a different track (internal, alpha, beta), edit
`android/fastlane/Fastfile` and add the `track:` parameter to the `supply`
call.

## Common errors

```terminal
[E] Changelog required for update mode
    No changelog found in .flow_deploy.json
exit 1
```
You can ship `beta` without changelogs, but `update` requires them. Add at
least one locale to `android.changelog` / `ios.changelog`.

```terminal
Fastlane error: app version mismatch
   Local pubspec: 1.4.0+87
   App Store Connect highest build: 87
   You must bump the build number before uploading.
```
Add `--increment-version` to the next run, or bump manually with
`flow deploy version --build`.

```terminal
Fastlane error: deliver — your app is currently in "Waiting for Review"
exit 1
```
You already submitted a previous build that hasn't been processed yet.
Either wait, or in App Store Connect remove the in-review submission first.

:::warn `update` is irreversible
Once a binary is in App Review, it's hard to pull back. Verify your changelogs
and that you're on the right `flavor` / `target` before running.
:::

:::tip Internal-track Android releases
For internal track Android, prefer `flow deploy beta --provider firebase
-p android` over a custom `track:` parameter. Firebase App Distribution is
designed for this; the Play internal track is more for staged production
rollouts.
:::
