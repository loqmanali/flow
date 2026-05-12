# `flow flavor replace`

Atomically renames an existing flavor across the entire project. Uses a
pre-flight snapshot so a half-completed rename never leaves the project
unbuildable.

## Synopsis

```bash
flow flavor replace
```

There are no arguments — the command always prompts.

## How the atomic rename works

1. **Snapshot** — every file the command might modify is copied to a
   temporary backup directory. The list includes:
   - `.flow_flavor.json`
   - `<app_config_path>`
   - `lib/main_<old>.dart`
   - `android/app/build.gradle`
   - `ios/Runner.xcodeproj/project.pbxproj`
   - `ios/Flutter/<old>.xcconfig`
   - `ios/Runner.xcodeproj/xcshareddata/xcschemes/<old>.xcscheme`
   - `.vscode/launch.json`
   - Firebase-related files if Firebase is wired
2. **Apply** — each file is rewritten with `<old>` → `<new>` and matching
   path renames.
3. **Verify** — if any step throws, every snapshotted file is restored
   verbatim, and the temp directory is cleaned up.
4. **Commit** — on success, `.flow_flavor.json` is updated last (after
   everything else has succeeded).

This means you'll never end up with `lib/main_qa.dart` while
`.flow_flavor.json` still lists `staging` — the rename is all-or-nothing.

## Walkthrough

```terminal
$ flow flavor replace
? Select the flavor to rename: › staging
? New name: › qa
? Confirm: rename "staging" → "qa" across the project? › Yes

✓ Snapshot created (8 files)
✓ Renamed lib/main_staging.dart → lib/main_qa.dart
✓ Renamed ios/Flutter/staging.xcconfig → ios/Flutter/qa.xcconfig
✓ Renamed Xcode scheme staging → qa
✓ Updated android/app/build.gradle
✓ Updated .vscode/launch.json
✓ Regenerated lib/core/config/app_config.dart
✓ Updated .flow_flavor.json (production_flavor unchanged)
✓ Snapshot discarded

Done.
```

## Production flavor handling

If you rename the `production_flavor`, the field is updated automatically —
the production flavor keeps its identity, just under a new name.

## Common errors

### Rollback example

If something fails mid-way:

```terminal
$ flow flavor replace
…
✓ Renamed lib/main_staging.dart → lib/main_qa.dart
✗ Failed updating android/app/build.gradle: gradle file is read-only

⚠ Rolling back from snapshot...
✓ Restored lib/main_staging.dart
✓ Restored android/app/build.gradle
✓ Snapshot discarded

The project was returned to its pre-rename state. Fix the underlying issue
and re-run.
exit 1
```

### Name conflicts

```terminal
❌ flow: new name "qa" is already present in flavors. Pick a different name
   or delete the existing "qa" first.
```

### Invalid identifier

```terminal
❌ flow: "QA" is not a valid flavor name. Must match [a-z][a-z0-9]*
```

:::tip Why no positional args?
`replace` insists on the interactive picker so you can't accidentally rename
the wrong flavor by typo (e.g. `flow flavor replace prod` when you have
both `prod` and `production`). The cost of two extra keystrokes is worth the
guard rail for an irreversible action.
:::
