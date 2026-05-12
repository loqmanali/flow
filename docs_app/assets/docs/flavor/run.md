# `flow flavor run`

A standardized wrapper around `flutter run` that handles `--flavor`,
`--target`, and `--dart-define` for you.

## Synopsis

```bash
flow flavor run [<flavor>] [<mode>]
```

## Arguments

| Position | Description |
|---|---|
| `<flavor>` | Optional. The flavor name. If omitted, you're prompted with a picker. |
| `<mode>` | Optional. One of `debug` / `release` / `profile`. Defaults to `debug`. |

## What it does

1. Loads `.flow_flavor.json` and resolves the entry point:
   - If `use_separate_mains: true`, uses `lib/main_<flavor>.dart`.
   - Otherwise, uses `lib/main.dart`.
2. Builds the argument list for `flutter run`:
   - `--flavor <flavor>`
   - `--target <entry-point>`
   - `--dart-define=FLAVOR=<flavor>`
   - One `--dart-define=<field>=<value>` for every key in `fields` + matching
     `values.<flavor>`.
3. Adds `--release` / `--profile` if requested.
4. Exec's `flutter run` and streams its output.

## Walkthrough

```terminal
$ flow flavor run dev
→ flutter run \
    --flavor dev \
    --target lib/main_dev.dart \
    --dart-define=FLAVOR=dev \
    --dart-define=baseUrl=https://dev.api.acme.com \
    --dart-define=debug=true \
    --dart-define=maxRetries=3
Launching lib/main_dev.dart on iPhone 16 Pro in debug mode...
Running Xcode build...                                                  
 └─Compiling, linking and signing...                         5.4s
Xcode build done.                                            18.7s
Syncing files to device iPhone 16 Pro...                             92ms

Flutter run key commands.
r Hot reload. 🔥🔥🔥
R Hot restart.
h List all available interactive commands.
d Detach (terminate "flutter run" but leave application running).
c Clear the screen
q Quit (terminate the application on the device).
```

## Release / profile mode

```bash
flow flavor run production release
flow flavor run staging profile
```

```terminal
$ flow flavor run production release
→ flutter run --release \
    --flavor production \
    --target lib/main_production.dart \
    --dart-define=FLAVOR=production \
    --dart-define=baseUrl=https://api.acme.com \
    --dart-define=debug=false \
    --dart-define=maxRetries=5
…
```

## Interactive mode

```terminal
$ flow flavor run
? Pick a flavor: › dev / stage / production
? Build mode: › debug / release / profile
…
```

## What gets passed where

| Source | Becomes |
|---|---|
| `flavors[i]` | `--flavor <name>` |
| Entry point resolution | `--target lib/main_<name>.dart` or `lib/main.dart` |
| Implicit | `--dart-define=FLAVOR=<name>` |
| `fields` + `values.<name>` | One `--dart-define=<field>=<value>` per key |

So inside your app, `String.fromEnvironment('baseUrl')` always returns the
correct value for the running flavor — and `AppConfig` (the generated class)
reads them at startup.

## Common errors

```terminal
❌ flow: unknown flavor "qa"
```
Pick from the listed flavors.

```terminal
❌ flow: entry point "lib/main_dev.dart" not found
   Did you delete it? Run `flow flavor init --from .flow_flavor.json` to
   regenerate.
```

```terminal
❌ flow: .flow_flavor.json not found. Run init first.
```

:::tip Pass extra flutter run args
Currently `flow flavor run` doesn't forward unknown arguments. If you need
`-d <device>` or `--web-port`, run the printed `flutter run …` command
directly — copy it from the first line of `flow flavor run`'s output.
:::
