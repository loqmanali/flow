## 0.1.0

Initial release.

### Flavor commands
- `flow flavor init` / `init --from <path>` — interactive or non-interactive flavor setup
- `flow flavor add <name>` — add a new flavor
- `flow flavor delete [name]` — safely remove a flavor
- `flow flavor replace` — atomically rename a flavor across the project
- `flow flavor reset` — restore the project to a single-flavor state
- `flow flavor run <flavor>` — `flutter run` with flavor + `--dart-define` injection
- `flow flavor build <target> <flavor>` — `flutter build` with flavor + `--dart-define`
- `flow flavor firebase` — `flutterfire configure` across all flavors
- `flow flavor migrate` — migrate `.flow_flavor.json` to the latest schema

### Deploy commands
- `flow deploy init` — interactive deployment config wizard
- `flow deploy beta` — TestFlight / App Store Connect / Firebase App Distribution
- `flow deploy update` — submit app updates to the stores
- `flow deploy version` — semver + build-number management
- `flow deploy run <profile>` — run a named profile from `.flow_deploy.json`
- `flow <profile>` — top-level shortcut for `flow deploy run <profile>`

### Engineering
- Single `flow` executable; `CommandRunner`-based dispatch with `--help` per command.
- Strict analyzer (`strict-casts`, `strict-inference`, `strict-raw-types`).
- Terse error reporting via `Chain.capture()` + POSIX exit codes (`package:io`).
- Integration tests with `test_process` + `test_descriptor`.
