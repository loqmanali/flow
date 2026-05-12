# `flow flavor add`

Adds one new flavor to an existing setup without touching the others.

## Synopsis

```bash
flow flavor add [<name>]
```

## Arguments

| Position | Description |
|---|---|
| `<name>` | Optional. If omitted, you'll be prompted. Must be a valid identifier (`[a-z][a-z0-9]*`) and not already in `flavors`. |

## What it does

1. Loads and validates `.flow_flavor.json`.
2. Appends the new name to `flavors`.
3. Initializes empty per-flavor values for every key in `fields` — you fill
   them in afterwards by editing `.flow_flavor.json`.
4. Regenerates everything platform-side:
   - Android `productFlavors`.
   - iOS Xcode scheme + build configurations + `ios/Flutter/<flavor>.xcconfig`.
   - `lib/main_<flavor>.dart` (when `use_separate_mains: true`).
   - `.vscode/launch.json` entry.
5. Regenerates `AppConfig` so the new flavor appears in the enum and the
   switch statement.

Firebase wiring is **not** updated automatically — run `flow flavor firebase
--flavor <name>` after filling in the new Firebase project ID.

## Walkthrough — argument mode

```terminal
$ flow flavor add staging
✓ Loaded .flow_flavor.json (3 flavors)
✓ Added "staging" to flavors
✓ Generated lib/main_staging.dart
✓ Wrote ios/Flutter/staging.xcconfig
✓ Updated android/app/build.gradle
✓ Updated .vscode/launch.json
✓ Regenerated lib/core/config/app_config.dart

⚠ Per-flavor values for "staging" are blank. Open .flow_flavor.json and
  fill in:
    values.staging.baseUrl
    values.staging.debug

Run `flow flavor firebase --flavor staging` once you've added the Firebase
project for it.
```

## Walkthrough — prompt mode

```terminal
$ flow flavor add
? New flavor name: › qa
✓ Loaded .flow_flavor.json (3 flavors)
✓ Added "qa" to flavors
…
```

## What it touches

| File | Change |
|---|---|
| `.flow_flavor.json` | Adds the new name to `flavors`; adds an empty object under `values.<name>` for each `fields` key |
| `lib/main_<name>.dart` | Created when `use_separate_mains: true` |
| `<app_config_path>` | Regenerated with the new enum value + switch case |
| `android/app/build.gradle` | New entry under `productFlavors` |
| `ios/Runner.xcodeproj` | New scheme + `<name>-Debug` / `<name>-Release` build configurations |
| `ios/Flutter/<name>.xcconfig` | Created |
| `.vscode/launch.json` | New "Flutter: <name>" configuration |

## Common errors

```terminal
❌ flow: flavor "staging" already exists
```
Pick a different name or `flow flavor delete staging` first.

```terminal
❌ flow: .flow_flavor.json not found. Run init first.
```
You must `flow flavor init` before `add`.

:::tip Fill values before running
After `add`, the new flavor lives in `flavors` but has empty values. If you
try to `flow flavor run <new>` without filling them in, the app will boot
with empty strings / default-zero numbers. Edit `.flow_flavor.json` first.
:::
