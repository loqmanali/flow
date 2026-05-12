# `flow flavor delete`

Safely removes one flavor and every artifact tied to it.

## Synopsis

```bash
flow flavor delete [<name>]
```

## Arguments

| Position | Description |
|---|---|
| `<name>` | Optional. If omitted, you're shown a picker of the existing flavors. |

## Safety rules

- A project must keep **at least two flavors**. Attempting to delete down
  to one is blocked; you'll be offered a full project reset instead (see
  [`flow flavor reset`](/flavor/reset)).
- Deleting the **production flavor** triggers an extra prompt: you must
  nominate a replacement so the base package ID has somewhere to live.
- Deletion is destructive on disk — the per-flavor xcconfig, Gradle entry,
  main file, launch.json entry, and `AppConfig` enum entry are all removed.
  `.flow_flavor.json` is updated last so the file system stays consistent if
  something fails mid-way.

## Walkthrough — non-production flavor

```terminal
$ flow flavor delete staging
? Are you sure you want to delete "staging"? › Yes
✓ Removed staging from flavors
✓ Deleted lib/main_staging.dart
✓ Deleted ios/Flutter/staging.xcconfig
✓ Removed staging from android/app/build.gradle productFlavors
✓ Removed staging from .vscode/launch.json
✓ Removed staging from ios/Runner.xcodeproj schemes
✓ Regenerated lib/core/config/app_config.dart
✓ Updated .flow_flavor.json
```

## Walkthrough — production flavor

```terminal
$ flow flavor delete production
⚠ "production" is the current production_flavor.
? Choose a new production flavor: › staging
? Confirm: delete "production" and promote "staging" to production_flavor? › Yes
✓ Promoted "staging" to production_flavor (it now uses the base package ID)
✓ Removed production from flavors
…
```

## Walkthrough — last two flavors

```terminal
$ flow flavor delete stage
⚠ Deleting "stage" would leave fewer than 2 flavors.
? Reset the project instead (removes ALL flavor configuration)? › Yes
✓ Running full project reset...
```

If you say "No", the command aborts and no files are changed.

## What it touches

For a flavor `<name>`:

| File / directory | Change |
|---|---|
| `.flow_flavor.json` | Removes `<name>` from `flavors` and `values`; removes per-flavor Firebase project mapping |
| `lib/main_<name>.dart` | Deleted |
| `<app_config_path>` | Regenerated without the enum/case |
| `android/app/build.gradle` | The `<name>` block under `productFlavors` is removed |
| `ios/Runner.xcodeproj` | Scheme + per-flavor build configurations removed |
| `ios/Flutter/<name>.xcconfig` | Deleted |
| `.vscode/launch.json` | "Flutter: <name>" entry removed |
| Firebase `firebase_options_<name>.dart` | Removed when present |

## Common errors

```terminal
❌ flow: cannot delete "production" — no other flavor can take its place
   because production_flavor must always be set.
```
You tried to delete the only flavor configured as `production_flavor` and
there are no others to promote. Add a new flavor first.

```terminal
❌ flow: unknown flavor "qa"
```
The name doesn't exist in `flavors`. Check `.flow_flavor.json`.

:::warn Generated `firebase_options_*.dart` may be regenerated empty
If the deleted flavor had Firebase setup, the per-flavor `firebase_options_*`
file is removed. Other flavors are untouched — but if your `main` imports
the deleted options file, you'll get a build error. Fix the imports.
:::
