# First-time setup

A complete walkthrough from "I just ran `flutter create acme`" to "I can
ship a staging beta to TestFlight and Firebase App Distribution".

Estimated time: **30–60 minutes**, most of it spent in App Store Connect /
Google Play / Firebase consoles rather than the terminal.

## 0. Prerequisites

- A fresh or existing Flutter project that runs locally.
- An [Apple Developer Program](https://developer.apple.com/programs/)
  membership.
- A [Google Play Console](https://play.google.com/console) developer
  account.
- A Firebase project (free tier is fine).
- `flow` installed (see [Installation](/installation)).
- Fastlane installed: `brew install fastlane` (macOS).

## 1. Create the apps in each store

Before any automation, the apps must exist in the dashboards:

1. **App Store Connect** → **My Apps** → **+** → **New App**. Pick the bundle
   ID (which becomes `ios.app_identifier`). Repeat for each flavor if you
   use unique IDs.
2. **Google Play Console** → **Create app**. Set the package name (which
   becomes `android.package_name`). Upload a single internal-test bundle so
   the listing exists (you can do this from Android Studio just once — `flow`
   takes over after).
3. **Firebase Console** → **Add project** for each flavor you want isolated.
   Inside each, register the Android and iOS apps using the same bundle /
   application IDs you set up above.

:::warn You can't automate app creation
Apple and Google both require manual creation through their consoles before
any API uploads will succeed. This step is unavoidable.
:::

## 2. Set up flavors

```bash
flow flavor init
```

Answer the wizard ([full walkthrough](/flavor/init#interactive-mode-walkthrough)).
Use the same bundle IDs you registered in the stores.

After the wizard finishes:

```terminal
$ flow flavor run dev
…
Launching lib/main_dev.dart on iPhone 16 Pro in debug mode...
```

If the app launches and reads the right `baseUrl`, flavors are set up
correctly.

## 3. Wire up Firebase

```bash
flow flavor firebase
```

`flutterfire` will write `lib/firebase_options_<flavor>.dart` for each
flavor, and `flow` will inject `Firebase.initializeApp` into each
`lib/main_<flavor>.dart`.

Re-run the app to confirm Firebase initializes without errors.

## 4. Generate App Store Connect API key

Follow the steps in [Where to get values → App Store
Connect](/config/where-to-get-values#app-store-connect). Save the `.p8` to
`secrets/AuthKey_<key_id>.p8` and note the `key_id` and `issuer_id`.

## 5. Generate Google Play service account JSON

Follow the steps in [Where to get values → Google
Play](/config/where-to-get-values#google-play). Save the JSON to
`secrets/google-play-service-account.json`.

## 6. Collect Firebase App IDs

Follow [Where to get
values → Firebase](/config/where-to-get-values#firebase). You'll end up
with up to 2N IDs (Android + iOS per flavor, if you ship to both).

## 7. Set up deployment

```bash
flow deploy init
```

Pick **Both (fastlane + firebase)** and **Yes** to flavor configuration.

Then open `.flow_deploy.json` and replace every `(Required)` placeholder
with the real value from steps 4–6.

For internal-only TestFlight (recommended for the first try), keep
`ios.testflight.enable_external_testing: false` — you don't need any of the
other `testflight.*` fields.

## 8. Add secrets to `.gitignore`

```
secrets/
.flow_deploy.json
```

You might keep `.flow_deploy.json` in `.gitignore` for now while you're
experimenting, then later commit a version with placeholders + load real
values via environment variables in CI.

## 9. Ship a staging beta

```bash
flow staging
```

If everything is wired up, this builds both platforms, uploads Android to
Firebase App Distribution, and uploads iOS to TestFlight. Total time:
~6–15 minutes depending on your machine.

```terminal
$ flow staging
✓ Loaded .flow_deploy.json
ℹ Deployment profile: staging
ℹ Deployment provider: mixed (android→firebase, ios→fastlane)
…
✓ Built …app-staging-release.aab
✓ Built …Acme Staging.ipa
✓ Uploaded to Firebase App Distribution
  → Invitations sent to "qa-team" (3 testers)
✓ TestFlight processing started (~5-10 min until testers see it)

Done.
```

## 10. Verify in the dashboards

- **Firebase Console** → your staging project → **App Distribution** →
  Android app → you should see your build with status **Available**.
- **App Store Connect** → your app → **TestFlight** → **iOS Builds** →
  status starts as **Processing**, becomes **Ready to Submit** in 5–15
  minutes for internal testing.

## What you have now

- One-command beta deploys for staging.
- Reproducible flavor setup — teammates can `flow flavor init --from
  .flow_flavor.json` on a fresh checkout.
- A pubspec version that bumps via `flow deploy version` (no more
  hand-editing).

Next steps:

- [TestFlight beta workflow](/workflows/testflight-beta) — opening up to
  external testers.
- [Mixed provider workflow](/workflows/mixed-provider) — fine-tuning the
  Android/iOS split.
- [Version bumping workflow](/workflows/version-bumping) — patterns for
  release branches and hotfixes.
