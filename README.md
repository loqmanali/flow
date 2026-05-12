# flow

**One CLI for the full Flutter app lifecycle:** configure flavors, build, version, and ship.

`flow` covers the work most teams duplicate across every Flutter project:

- Wire up build flavors (Android `productFlavors`, Xcode schemes, `.xcconfig`, `--dart-define`, VS Code launch configs).
- Set up Firebase per flavor without typing the same `flutterfire configure` invocation 4× in a row.
- Build and ship to TestFlight, the App Store, Google Play, or Firebase App Distribution.
- Manage version numbers and build numbers without hand-editing `pubspec.yaml`.

All of it lives behind a single command: `flow`.

---

## Install

```bash
dart pub global activate flow
```

After activation, the `flow` command is available globally on your `PATH`.

## At a glance

```bash
flow                                # prints help
flow --version

# Flavor setup
flow flavor init                    # interactive wizard
flow flavor init --from .flow_flavor.json   # non-interactive
flow flavor add staging
flow flavor run dev
flow flavor build apk production
flow flavor firebase
flow flavor reset

# Deployment
flow deploy init                    # generate .flow_deploy.json
flow deploy beta -p ios
flow deploy update --provider mixed
flow deploy version --patch
flow deploy run dev                 # named profile
flow dev                            # shortcut for `flow deploy run dev`
```

Use `flow help <command>` for the full option list of any subcommand.

---

## Commands

### `flow flavor`

| Subcommand | What it does |
|---|---|
| `init [--from <path>]` | Interactive wizard, or non-interactive load from an existing `.flow_flavor.json` |
| `add [<name>]` | Add a flavor without touching others |
| `delete [<name>]` | Remove a flavor (refuses to leave < 2 flavors; offers a full reset instead) |
| `replace` | Atomically rename a flavor across the project (uses a pre-flight snapshot) |
| `reset` | Restore the project to its original, non-flavored state |
| `run [<flavor>] [<mode>]` | `flutter run` with the correct `--flavor`, `--target`, and `--dart-define` injection |
| `build [<target>] [<flavor>]` | `flutter build` with the same wiring |
| `firebase [--flavor <name>]` | Configure Firebase across all flavors (or a single one) via `flutterfire` |
| `migrate` | Update `.flow_flavor.json` to the latest schema |

### `flow deploy`

| Subcommand | What it does |
|---|---|
| `init` | Interactive wizard producing `.flow_deploy.json` |
| `beta [--platform p] [--provider r] [--flavor f] [--target t]` | Build + upload to TestFlight or Firebase App Distribution |
| `update [...]` | Submit app updates to App Store Connect / Google Play |
| `run <profile> [...]` | Run a named profile from the config (or use the shortcut `flow <profile>`) |
| `version [--major\|--minor\|--patch\|--build\|--set X]` | Show or change the `pubspec.yaml` version + build number |

Top-level `flow deploy` (no subcommand) launches the interactive wizard.

---

## Configuration files

`flow` keeps the two concerns in separate files so each command group can be
adopted independently.

* **`.flow_flavor.json`** — flavor list, `AppConfig` schema, package IDs,
  Firebase strategy.
* **`.flow_deploy.json`** — fastlane credentials, Firebase App Distribution
  IDs, profiles, changelogs.

Run `flow flavor init` or `flow deploy init` to bootstrap either file
interactively — the wizard validates every field before writing the file.

---

## Development

* `bin/flow.dart` — thin entry point. Wraps the runner in `Chain.capture()`
  (terse stack traces) and uses `ExitCode` from `package:io` for POSIX exit
  codes.
* `lib/src/runner.dart` — `CommandRunner<int>` factory.
* `lib/src/commands/` — `Command<int>` subclasses for each user-facing
  subcommand.
* `lib/src/flavor/` and `lib/src/deploy/` — internal implementation
  (services, models, templates, process runners).
* `test/integration/` — `test_process` + `test_descriptor` end-to-end tests.

Strict analyzer is enabled (`strict-casts`, `strict-inference`,
`strict-raw-types`). Run the standard validation chain before committing:

```bash
dart format . --set-exit-if-changed
dart analyze
dart test
```

## License

BSD 3-Clause. See [LICENSE](LICENSE).
