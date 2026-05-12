# Installation

`flow` is published as a Dart package; activating it globally registers the
`flow` executable on your `PATH`.

## Requirements

| Tool | Why | Required? |
|---|---|---|
| **Dart SDK ≥ 3.7.2** | Runs the CLI | Always |
| **Flutter SDK** | `flow flavor run` / `build` wrap `flutter run` / `flutter build` | Most users |
| **Fastlane** | TestFlight, App Store, and Google Play uploads | Only for store delivery |
| **Firebase CLI** | Firebase App Distribution uploads | Only for FAD delivery |
| **`flutterfire` CLI** | `flow flavor firebase` | Only if you set Firebase up per flavor |
| **App Store Connect API key (`.p8`)** | iOS uploads via Fastlane | iOS store delivery |
| **Google Play service account JSON** | Android uploads via Fastlane | Android store delivery |

:::info About Fastlane
Store delivery still runs through Fastlane under the hood. `flow` generates the
Fastlane configuration for you, so you don't need to author `Fastfile`s or
`Appfile`s by hand — but Fastlane itself must be installed on your machine
(`brew install fastlane` or `gem install fastlane`).
:::

## Global activation

The recommended path for everyday use:

```bash
dart pub global activate flow
```

After activation, the `flow` command is available globally. Run `flow --help`
to confirm.

### Confirming the install

```terminal
$ flow --version
flow v0.1.0

$ flow --help
Flutter flavor + deployment CLI (v0.1.0).

Usage: flow <command> [arguments]

Global options:
-h, --help       Print this usage information.
-v, --version    Print the current flow version and exit.

Available commands:
  deploy    Build and ship to TestFlight, the stores, or Firebase App Distribution.
  flavor    Configure and manage Flutter build flavors.
```

If `flow` is not recognized after activation, ensure your shell's `PATH`
includes Dart's global executables directory. On macOS / Linux that is usually
`~/.pub-cache/bin`.

```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

Append that line to `~/.zshrc` or `~/.bashrc` to make it permanent.

## Installing from source

If you want to test an unreleased version or contribute:

```bash
dart pub global activate --source path /path/to/flow
```

This creates a global `flow` command linked to your local source tree. Dart
code changes are picked up immediately on the next invocation; pubspec changes
require re-running the activate command.

To revert to the published version:

```bash
dart pub global activate flow
```

## As a dev dependency

You can also pin `flow` to a specific project — useful when teammates need to
run an exact version without globally installing anything.

```yaml
# pubspec.yaml
dev_dependencies:
  flow:
    git:
      url: https://github.com/loqmanali/flow.git
      ref: main
```

Then call it through `dart run`:

```bash
dart run flow flavor init
dart run flow deploy beta -p ios
```

:::tip Which install method should I use?
**Global activation** for individual developers — fastest to invoke.
**Dev dependency** for shared teams — guarantees everyone uses the same `flow`
version, which is what you want when CI and humans both call the CLI.
:::

## Updating

For a global install, re-run the activate command:

```bash
dart pub global activate flow
```

For a dev-dependency install, bump the `ref` in your `pubspec.yaml` and run
`dart pub get`.

## Uninstalling

```bash
dart pub global deactivate flow
```
