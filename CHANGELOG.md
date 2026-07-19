## 0.3.0

### Breaking
- **Dropped the hardcoded `SAMNAN_BUILD_FLAVOR` env var.** Builds now export only `FLOW_BUILD_FLAVOR`, the generic, tool-agnostic flavor signal. A project whose native flavor guard reads `SAMNAN_BUILD_FLAVOR` must rename it to `FLOW_BUILD_FLAVOR` (in its Gradle guard, Xcode run-script, `tool/flavor.dart`, and `.vscode/launch.json`). One project's name never belonged in a shared tool.

### Fixed
- **`build.target` was silently ignored.** The deploy command read the configured target, printed it in the run summary, then dropped it — every build hardcoded `lib/main_<flavor>.dart`. A project whose entrypoints don't follow that naming was told it was building one target while it built another. The configured target is now passed through, with the convention kept as the fallback.
- **Flavored builds could ship with no compile-time config.** `--dart-define-from-file` was resolved only from the `.env.<flavor>` convention, and a missing file returned no arguments *silently*. A project that names env files differently (`.env` for a `dev` flavor) built and uploaded a release whose `String.fromEnvironment` values were all empty — an artifact that installs fine and is dead on launch. Resolution is now explicit-first and never fails quietly.

### Added
- **`build.dart_define_from_file`** — an explicit env file path per profile (`dev` → `.env`, `production` → `.env.production`), overriding the `.env.<flavor>` convention. A configured file that doesn't exist is now a hard error rather than a silently define-less build; when nothing is configured and no conventional file is found, a flavored build warns instead of passing silently.
- **`android.track`** — the Play Console track to publish to (`internal`, `alpha`, `beta`, `production`). Previously `supply` was called with no track, so every Android upload went to `production` and testing tracks were unreachable. Defaults to `production`, so existing configs are unaffected.
- Tests covering dart-define resolution and target selection (`test/deploy/build_arguments_test.dart`).

### Changed
- `BuildService.flavorBuildArguments` / `dartDefineArguments` are now public, so the CLI, Flow Studio, and tests can inspect what a deploy would pass without running a build. Both take an optional `projectDir`, defaulting to the current working directory, so callers can resolve against a directory without mutating process-wide `Directory.current`.
- `pubspec.yaml` version now matches the changelog — it still read `0.1.0` after the 0.2.0 entry, so `flow --version` under-reported the running build.

## 0.2.0

### Flow Studio (new)
- Add `flow_studio`, a Flutter desktop (macOS) GUI for the flow engine — project picker with recent projects, flavor management, a deploy screen, an init wizard, and a live log console.
- Studio imports the engine directly via a path dependency instead of shelling out to the `flow` executable, so both frontends run the exact same business logic.

### Engine embedding surface
- Add `lib/engine.dart` — the public embedding library for GUI frontends, exporting the deploy/flavor commands, config models, `ProcessRunner`, `PubspecUtils`, and the logger contract.
- `AppLogger` accepts an optional `AppLoggerInteraction` so embedders answer prompts with dialogs or fixed defaults instead of blocking on stdin, and an optional `messageSink` that mirrors every log line into a host UI. With both unset, CLI behavior is byte-for-byte unchanged.
- `ProcessRunner.outputSink` redirects subprocess stdout/stderr into an embedder's console; defaults to the terminal.
- `Constants`, `ProcessRunner`, and `PubspecUtils` resolve the project directory through a live getter rather than a field captured at class-load time, so embedders can retarget a project by setting `Directory.current`. The CLI's working directory never changes mid-run, so its behavior is identical.

### Refactoring
- Extract `DeployConfigInitializer` — the non-interactive core of `flow deploy init` (template composition, `.gitignore` handling, non-overwriting config writes). `InitCommand` now only collects answers and delegates, so the CLI and Studio share one implementation.

## 0.1.1

### Documentation
- Update installation instructions in README and docs to use `--source git` activation (`dart pub global activate --source git https://github.com/loqmanali/flow.git`) instead of the bare `dart pub global activate flow` form, which resolves to an unrelated legacy package on pub.dev.
- Add local path activation instructions (`--source path`) for development and fork testing.
- Add PATH troubleshooting note (`~/.pub-cache/bin`).
- Add warning callout in docs_app explaining the pub.dev name conflict.

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
