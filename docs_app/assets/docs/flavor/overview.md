# `flow flavor`

Configure and maintain Flutter build flavors. Every subcommand reads (and
some write) `.flow_flavor.json` at the project root.

## Subcommand index

| Command | What it does |
|---|---|
| [`init`](/flavor/init) | Interactive wizard, or non-interactive from `--from` |
| [`add`](/flavor/add) | Add a flavor to an existing setup |
| [`delete`](/flavor/delete) | Remove a flavor and its artifacts |
| [`replace`](/flavor/replace) | Atomically rename a flavor across the project |
| [`reset`](/flavor/reset) | Revert the project to a single-flavor state |
| [`run`](/flavor/run) | `flutter run` with the right `--flavor` / `--target` / `--dart-define` |
| [`build`](/flavor/build) | `flutter build` with the same wiring |
| [`firebase`](/flavor/firebase) | `flutterfire configure` across all flavors |
| [`migrate`](/flavor/migrate) | Bring an older `.flow_flavor.json` up to the current schema |

## Top-level options

```terminal
$ flow flavor --help
Configure and manage Flutter build flavors.

Usage: flow flavor <subcommand> [arguments]
-h, --help    Print this usage information.

Available subcommands:
  add        Add a new flavor to an existing setup.
  build      Build the project for a specific flavor (wraps flutter build).
  delete     Remove an existing flavor and its artifacts.
  firebase   Configure Firebase for all flavors via flutterfire.
  init       Initialize flavor setup in the current project.
  migrate    Migrate .flow_flavor.json to the latest schema.
  replace    Atomically rename an existing flavor across the project.
  reset      Revert the project to its original, non-flavored state.
  run        Run the project with a specific flavor (wraps flutter run).
```

## What "a flavor" means here

In `flow` terms, a flavor is a tuple of:

1. **A name** (`dev`, `staging`, `production`) — referenced everywhere.
2. **A package identifier** — base ID, optionally suffixed with `.<name>`.
3. **A set of typed runtime values** for fields declared in `AppConfig`.
4. **(Optional)** A Firebase project plus per-flavor `firebase_options_*.dart`.

Once flavors exist, **everything else flows from `.flow_flavor.json`** —
launch configurations, gradle product flavors, Xcode schemes, generated
Dart code, and Firebase wiring are all rebuilt by `flow` based on that one
file.

## What it does **not** do

- Edit your application's runtime code beyond the generated `AppConfig`
  class and (optionally) the per-flavor `lib/main_<flavor>.dart` entry
  points.
- Run code signing for you. Xcode schemes are created, but the signing team
  / provisioning profile is whatever Xcode picks up from your dev
  certificates.
- Replace `flutterfire configure`. Firebase setup wraps the official CLI;
  you must have `flutterfire` installed and authenticated.
