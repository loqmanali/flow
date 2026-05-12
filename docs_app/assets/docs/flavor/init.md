# `flow flavor init`

Bootstraps build flavors in a Flutter project. Two modes:

- **Interactive** (default) — runs a 9-step wizard.
- **Non-interactive** — `--from <path>` validates and applies an existing
  `.flow_flavor.json`.

## Synopsis

```bash
flow flavor init [--from <path>]
```

## Options

| Flag | Default | Description |
|---|---|---|
| `--from <path>` | _(unset)_ | Validate and apply an existing config file non-interactively. Useful in CI and for bootstrapping a project from a saved template. |

## Interactive mode walkthrough

1. **Flavor names**

   Pick a preset (`dev, production` or `dev, stage, production`) or enter
   your own comma-separated list. Names must be lowercase, alphanumeric, no
   spaces.

2. **AppConfig field schema**

   Define typed variables. Enter one per line in the form `<type> <name>`,
   e.g. `String baseUrl`. Type `done` to finish. Supported types:
   `String`, `bool`, `int`, `double`.

3. **AppConfig path**

   Where to write the generated `AppConfig` Dart file. Default:
   `lib/core/config/app_config.dart`.

4. **Main strategy**

   - Separate mains — one `lib/main_<flavor>.dart` per flavor (recommended).
   - Single main — `lib/main.dart` reads `--dart-define=FLAVOR=...` at
     runtime.

5. **App display name**

   Auto-detected from `pubspec.yaml`; override if your store name differs.

6. **Base package ID**

   Auto-detected from `android/app/build.gradle`. Confirm or override.

7. **Package ID strategy**

   - Unique IDs — non-production flavors get `.<flavor>` appended. Required
     for side-by-side installs.
   - Shared ID — every flavor uses the base ID.

8. **Firebase project ID** (optional)

   If you say yes, you'll be prompted for a strategy and one project ID per
   flavor. Skip and run `flow flavor firebase` later if you prefer.

9. **Per-flavor values**

   For each field defined in step 2, fill in the value for every flavor
   from step 1.

## Walkthrough — fresh project

```terminal
$ flow flavor init
✓ Detected existing pubspec.yaml — app name "Acme"
? Choose your flavor set: › dev, stage, production
? Define AppConfig fields (type name, "done" to finish): ›
  String baseUrl
  bool debug
  done
? AppConfig file path: › lib/core/config/app_config.dart
? Main strategy: › Separate mains
? App display name: › Acme
? Base package ID: › com.acme.app
? Package ID strategy: › Unique IDs (.dev, .stage)
? Configure Firebase now? › No
? baseUrl for dev: › https://dev.api.acme.com
? baseUrl for stage: › https://stage.api.acme.com
? baseUrl for production: › https://api.acme.com
? debug for dev: › true
? debug for stage: › true
? debug for production: › false

✓ Wrote .flow_flavor.json
✓ Generated lib/core/config/app_config.dart
✓ Updated android/app/build.gradle (productFlavors)
✓ Updated ios/Runner.xcodeproj (schemes + xcconfig)
✓ Wrote .vscode/launch.json
✓ Created lib/main_dev.dart, lib/main_stage.dart, lib/main_production.dart

Done. Run `flow flavor run dev` to launch the dev flavor.
```

## Walkthrough — `--from`

A typical CI use:

```bash
flow flavor init --from .flow_flavor.json
```

This validates every field, then runs the full setup non-interactively. Any
missing required field produces a fail-fast error with the JSON path:

```terminal
$ flow flavor init --from .flow_flavor.json
❌ flow: invalid config at ".flow_flavor.json"
   → "production_flavor" must be one of the declared flavors: [dev, stage, production]
exit 1
```

## What it touches

| File / directory | Action |
|---|---|
| `.flow_flavor.json` | Created (overwritten if it exists; silent overwrite in interactive mode) |
| `<app_config_path>` | Generated |
| `lib/main_<flavor>.dart` | Generated per flavor when `use_separate_mains: true` |
| `android/app/build.gradle` | Patched: `flavorDimensions`, `productFlavors`, suffix logic |
| `ios/Runner.xcodeproj/...` | Patched: schemes, build configurations, base/per-flavor xcconfigs |
| `ios/Flutter/<flavor>.xcconfig` | Generated per flavor |
| `.vscode/launch.json` | Patched: one configuration per flavor |
| `scripts/*.sh` | Generated when `generate_scripts: true` in the config |

`init` is **idempotent**: running it again with the same config produces
identical results. Pre-existing flavor configuration that doesn't match the
new config is replaced.

## Common errors

```terminal
❌ flow: AppConfig path "lib/foo.dart" is outside the project lib/ directory
```
The path must live under `lib/`. Move it.

```terminal
❌ flow: flavor name "dev-staging" is invalid
   Must match [a-z][a-z0-9]*
```
Underscores and hyphens are not supported — pick a single lowercase token.

```terminal
❌ flow: detected pre-existing flavor setup that flow did not create
   Run `flow flavor reset` first, or pass --force to overwrite
```
Currently `--force` is not implemented; run `flow flavor reset` to clean
the project, then re-run `init`.

:::tip Save the file to your repo
Commit `.flow_flavor.json` immediately after the first successful `init`.
Teammates can then run `flow flavor init --from .flow_flavor.json` to
reproduce the exact setup without re-answering the wizard.
:::
