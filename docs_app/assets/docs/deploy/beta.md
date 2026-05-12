# `flow deploy beta`

Build and upload for beta testing. Targets TestFlight (iOS) and / or
Firebase App Distribution (either platform) depending on `--provider`.

## Synopsis

```bash
flow deploy beta [--platform <ios|android>]
                 [--provider <fastlane|firebase|mixed>]
                 [--flavor <name>] [--target <path>]
                 [--skip-build] [--increment-version | --skip-version-increment]
```

## Options

| Flag | Short | Default | Effect |
|---|---|---|---|
| `--platform` | `-p` | both | Limit to one platform. Skipped platform is silently passed over. |
| `--provider` | `-r` | prompted | Which channel to upload through. |
| `--flavor` | `-f` | profile / config / none | Maps to `flutter --flavor`. |
| `--target` | `-t` | profile / config / none | Maps to `flutter --target`. |
| `--skip-build` | `-s` | `false` | Reuse existing `build/app/outputs/...` / `build/ios/ipa/*.ipa`. |
| `--increment-version` |  | `false` | Run `flow deploy version --patch` before building. |
| `--skip-version-increment` |  | `false` | Keep `pubspec.yaml` unchanged this run. |

## What happens, step by step

1. Resolve options against:
   - The deploy profile if one was implied (e.g. via `flow staging` ⇒ profile
     `staging`).
   - `.flow_deploy.json` top-level defaults.
   - CLI flags, which override everything else.
2. Validate the chosen provider's required fields. Fail fast if anything is
   missing.
3. (Unless `--skip-build`) build the artifact:
   - Android → `flutter build appbundle …`
   - iOS → `flutter build ipa …`
4. (Unless skipping) bump the version. Default per-config is
   `skip_version_increment: true`, so this step is typically a no-op unless
   `--increment-version` was set.
5. Hand the artifact to the provider:
   - `fastlane` (iOS) → `pilot` action → TestFlight
   - `firebase` → `firebase appdistribution:distribute …`
   - `mixed` → Android: Firebase; iOS: Fastlane pilot

## Walkthrough — `mixed` provider with profiles

```terminal
$ flow deploy beta --provider mixed
✓ Loaded .flow_deploy.json
ℹ Deployment provider: mixed (android→firebase, ios→fastlane)
ℹ Platform: all
ℹ Build flavor: staging
ℹ Build target: lib/main_staging.dart

→ flutter build appbundle --release --flavor staging \
    --target lib/main_staging.dart \
    --dart-define=FLAVOR=staging \
    --dart-define=baseUrl=https://stage.api.acme.com
✓ Built build/app/outputs/bundle/stagingRelease/app-staging-release.aab (24.3MB)

→ flutter build ipa --release --flavor staging \
    --target lib/main_staging.dart \
    --dart-define=FLAVOR=staging \
    --dart-define=baseUrl=https://stage.api.acme.com
✓ Built build/ios/ipa/Acme Staging.ipa (52.4MB)

→ firebase appdistribution:distribute build/app/outputs/bundle/stagingRelease/app-staging-release.aab \
    --app=1:1234567890:android:abc123def456 \
    --groups=qa-team \
    --release-notes="Build #246 — staging"
✓ Uploaded to Firebase App Distribution
  → Invitations sent to "qa-team" (5 testers)

→ fastlane ios beta
  ✓ pilot: build uploaded
  ✓ TestFlight processing started (~5-10 min until testers see it)

Done.
```

## Walkthrough — iOS only, skipping the build

Common when you've already built locally and want to retry the upload:

```terminal
$ flow deploy beta -p ios --provider fastlane --skip-build
✓ Loaded .flow_deploy.json
ℹ Skipping build process
ℹ Reusing build/ios/ipa/Acme Staging.ipa

→ fastlane ios beta
  ✓ pilot: build uploaded
  ✓ TestFlight processing started

Done.
```

## Walkthrough — Android only, Firebase

```terminal
$ flow deploy beta -p android --provider firebase
…
→ firebase appdistribution:distribute …
✓ Uploaded to Firebase App Distribution
  → Invitations sent to "qa-team" (3 testers)
  → Direct testers added: alice@acme.com, bob@acme.com
```

## Common errors

```terminal
[E] Missing ios.app_store_connect.key_id in .flow_deploy.json
[E] Missing ios.app_store_connect.issuer_id in .flow_deploy.json
[E] Missing ios.app_store_connect.key_filepath in .flow_deploy.json
exit 1
```
You picked `fastlane` or `mixed` for iOS but the App Store Connect API key
trio is empty. Fill them in.

```terminal
[E] Missing android.firebase_app_distribution.app_id in .flow_deploy.json
exit 1
```
You picked `firebase` for Android but the Firebase app ID is missing.

```terminal
[E] Mixed provider requires both platforms. Remove --platform or use --platform all.
exit 1
```
You can't use `mixed` with `-p ios` alone — the whole point of `mixed` is
"different provider for each platform".

```terminal
Error: TestFlight metadata is incomplete. enable_external_testing is true,
but ios.testflight.beta_app_feedback_email is missing.
exit 1
```
External testing requires every `testflight.*` field — see
[`.flow_deploy.json`](/config/deploy#iostestflight).

```terminal
Fastlane error: Could not find provisioning profile for "com.acme.app.staging"
```
This is a code-signing problem, not a `flow` problem. Open Xcode, select
the staging scheme, fix the signing setup, then re-run with `--skip-build`.

:::tip Internal-only TestFlight requires almost no config
If `ios.testflight.enable_external_testing` is `false` (the default), you
only need the App Store Connect API key trio. The upload becomes visible
to internal testers (people in your App Store Connect team) within ~5–10
minutes after Apple finishes processing. No review required.
:::
