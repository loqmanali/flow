# Mixed provider

The `mixed` provider uploads **Android via Firebase App Distribution** and
**iOS via TestFlight (Fastlane)** in a single command. This is the most
common beta setup for teams that:

- Want internal Android testers to get builds quickly (FAD has no review).
- Want iOS testers to use the TestFlight app (Apple has no equivalent
  third-party tool with the same install UX).

## Why split the providers?

| Concern | Android | iOS |
|---|---|---|
| In-app updater | Firebase App Distribution app on the device prompts testers when a new build lands. | TestFlight app prompts; Apple won't let third-party tools provide push installs. |
| Review for internal testers | None (FAD) | None for internal team members, ~24h for external groups. |
| Tester onboarding | Email invitation → install Firebase App Distribution → tap "Download". | Email invitation → install TestFlight → tap "Install". |

In practice, `mixed` is the smoothest path for beta cycles where Android
QA needs constant new builds (every PR merge) and iOS uses TestFlight as
the central distribution channel.

## Config requirements

```json
{
  "android": {
    "package_name": "com.acme.app.staging",
    "firebase_app_distribution": {
      "app_id": "1:1234567890:android:abc123def456",
      "groups": "qa-team"
    }
  },
  "ios": {
    "app_identifier": "com.acme.app.staging",
    "app_store_connect": {
      "key_id": "ABCD123456",
      "issuer_id": "12345678-1234-1234-1234-123456789012",
      "key_filepath": "secrets/AuthKey_ABCD123456.p8"
    },
    "testflight": {
      "enable_external_testing": false
    }
  }
}
```

You need:

- Android firebase app + tester groups configured.
- iOS App Store Connect API key (the trio).

You do **not** need iOS Firebase wiring or Android Fastlane service account.

## Invocation

```bash
flow deploy beta --provider mixed --platform all
```

Or via a profile:

```json
"staging": {
  "mode": "beta",
  "provider": "mixed",
  "platform": "all",
  "build": { "flavor": "staging", "target": "lib/main_staging.dart" }
}
```

```bash
flow staging
```

## Walkthrough

```terminal
$ flow staging
✓ Loaded .flow_deploy.json
ℹ Deployment profile: staging
ℹ Deployment provider: mixed (android→firebase, ios→fastlane)
ℹ Platform: all
ℹ Build flavor: staging
ℹ Build target: lib/main_staging.dart

→ flutter build appbundle --release --flavor staging …
✓ Built build/app/outputs/bundle/stagingRelease/app-staging-release.aab (24.3MB)

→ flutter build ipa --release --flavor staging …
✓ Built build/ios/ipa/Acme Staging.ipa (52.4MB)

→ firebase appdistribution:distribute build/app/outputs/bundle/stagingRelease/app-staging-release.aab \
    --app=1:1234567890:android:abc123def456 \
    --groups=qa-team \
    --release-notes="Build #246 — staging"
✓ Uploaded to Firebase App Distribution
  → Invitations sent to "qa-team" (5 testers)
  → Build available for download immediately

→ fastlane ios beta
  → pilot: uploading
  ✓ Build 246 uploaded
  ✓ TestFlight processing started (~5-10 min)

Done.
```

## Restriction — `--platform` must be `all`

`mixed` is meaningless with a single platform — that's just `firebase` or
`fastlane` directly. Passing `--platform ios` with `--provider mixed`
fails fast:

```terminal
❌ flow: Mixed provider requires both platforms. Remove --platform or use --platform all.
exit 1
```

## When to choose `mixed` over other combinations

| Goal | Best provider |
|---|---|
| Quick Android QA cycle, TestFlight for iOS | **mixed** |
| Both platforms via Firebase App Distribution | `firebase` |
| Both platforms via TestFlight / Play internal | `fastlane` |
| Production release | `fastlane` (via `flow deploy update`) |

## Common errors

```terminal
[E] Missing android.firebase_app_distribution.app_id in .flow_deploy.json
exit 1
```
The Android leg fails before iOS even starts. Fill in the Firebase app ID.

```terminal
[E] Missing ios.app_store_connect.key_id in .flow_deploy.json
exit 1
```
Same idea for the iOS leg.

```terminal
firebase: Error: HTTP error 401 (UNAUTHENTICATED)
   The Firebase CLI is not signed in or the token expired.
```
Run `firebase login` (or set `FIREBASE_TOKEN` for CI).

:::tip Use `mixed` for the staging profile, `fastlane` for production
A common, clean setup: `staging` uses `mixed` (so QA gets fast Android
builds), `production` uses `fastlane` with `mode: update` (so public
releases go through stores). Both can coexist in `.flow_deploy.json`.
:::
