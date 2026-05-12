# Quick start

The fastest path from "fresh `flutter create`" to a working flavored app with
a deployable beta build.

## 0. Prerequisites

You have Flutter installed, a project that runs locally on at least one
platform, and `flow` installed (see [Installation](/installation)).

## 1. Set up flavors

From the project root:

```bash
flow flavor init
```

The interactive wizard walks you through nine steps:

1. **Flavor names** — pick a preset (`dev, production` or `dev, stage,
   production`) or enter your own list.
2. **AppConfig fields** — define the typed variables your app reads at
   runtime (e.g. `String baseUrl`, `bool debug`).
3. **AppConfig path** — where to generate the file (default
   `lib/core/config/app_config.dart`).
4. **Main strategy** — separate entry points (`lib/main_<flavor>.dart`) or a
   single `lib/main.dart` that branches on `--dart-define=FLAVOR=...`.
5. **App display name**.
6. **Base package ID** (auto-detected from `build.gradle` when possible).
7. **Package ID strategy** — unique IDs per flavor (`com.example.app.dev`) or
   shared across all flavors.
8. **Firebase project ID** — optional.
9. **Per-flavor values** — fill in the values for every field across every
   flavor.

Expected output:

```terminal
$ flow flavor init
✓ Detected existing pubspec.yaml — app name "Acme"
? Choose your flavor set: › dev, stage, production
? Define AppConfig fields (type name): ›
  String baseUrl
  bool debug
  done
? AppConfig file path: › lib/core/config/app_config.dart
? Main strategy: › Separate mains
? App display name: › Acme
? Base package ID: › com.acme.app
? Package ID strategy: › Unique IDs (.dev, .stage)
? Configure Firebase now? › Yes
? Firebase project ID: › acme-app
? baseUrl for dev: › https://dev.api.acme.com
? baseUrl for stage: › https://stage.api.acme.com
? baseUrl for production: › https://api.acme.com
? debug for dev: › true
? debug for stage: › true
? debug for production: › false

✓ Wrote .flow_flavor.json
✓ Generated lib/core/config/app_config.dart
✓ Updated android/app/build.gradle
✓ Updated ios/Runner.xcodeproj
✓ Wrote .vscode/launch.json
✓ Created lib/main_dev.dart, lib/main_stage.dart, lib/main_production.dart

Done. Run `flow flavor run dev` to launch the dev flavor.
```

## 2. Run a flavor

```bash
flow flavor run dev
```

This wraps `flutter run` and injects `--flavor`, `--target`, and every
`AppConfig` value as `--dart-define`:

```terminal
$ flow flavor run dev
→ flutter run --flavor dev --target lib/main_dev.dart \
    --dart-define=FLAVOR=dev \
    --dart-define=baseUrl=https://dev.api.acme.com \
    --dart-define=debug=true
Launching lib/main_dev.dart on iPhone 16 Pro in debug mode...
```

## 3. Set up deployment

```bash
flow deploy init
```

The wizard asks two questions:

1. **Which provider?** — fastlane, firebase, or both.
2. **Include flavor config?** — when yes, profiles are pre-wired for `dev`,
   `staging`, and `production` and reference your `--flavor` / `--target`.

Expected output:

```terminal
$ flow deploy init
? Provider template: › Both (fastlane + firebase)
? Include flavor configuration? › Yes
✓ Wrote .flow_deploy.json
  Next: open the file and fill in the values marked "(Required)".
```

Open `.flow_deploy.json` and replace the placeholders. The fields you need to
fill in are listed under [`.flow_deploy.json`](/config/deploy) with a
"where to get this value" pointer for each one.

## 4. Ship a beta

Once `.flow_deploy.json` is filled in:

```bash
flow deploy beta --provider mixed
```

`mixed` uploads Android to Firebase App Distribution and iOS to TestFlight in
a single invocation. For more granular control, see
[`flow deploy beta`](/deploy/beta) and the
[TestFlight beta workflow](/workflows/testflight-beta).

## What you have now

After these four commands:

- `.flow_flavor.json` — flavor source of truth
- `.flow_deploy.json` — deployment source of truth
- `lib/core/config/app_config.dart` — typed runtime config
- `lib/main_<flavor>.dart` — entry points per flavor
- Updated Android Gradle + iOS Xcode configuration
- `.vscode/launch.json` with one launch configuration per flavor
- (Optional) Fastlane files under `ios/fastlane/` and `android/fastlane/`

:::tip You don't have to do all of this
Each step is independent. A team that already has flavors set up manually can
skip step 1 entirely — `flow deploy init` works without `.flow_flavor.json`.
A library author who never publishes to stores can use only `flow flavor` and
ignore `flow deploy`.
:::
