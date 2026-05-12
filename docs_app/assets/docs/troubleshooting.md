# Troubleshooting

Common errors, what they mean, and how to fix them. Organized by where
the error originates.

## `flow` itself

### `❌ flow: invalid config at ".flow_flavor.json"`

The JSON parsed but a required field is missing or invalid. The next line
tells you exactly which field. Refer to
[`.flow_flavor.json` reference](/config/flavor) for valid values.

### `❌ flow: unknown flavor "qa"`

The flavor name doesn't exist in `flavors`. Check `.flow_flavor.json` and
spelling. To list known flavors:

```bash
flow flavor --help        # subcommand list — not a flavor list
cat .flow_flavor.json | grep -A 5 flavors
```

### `❌ flow: detected pre-existing flavor setup that flow did not create`

`flow flavor init` is conservative: if Android product flavors or iOS
schemes exist that didn't come from `flow`, it refuses to clobber them.
Run [`flow flavor reset`](/flavor/reset) first, **or** delete the offending
blocks manually, then re-run `init`.

### `❌ flow: .flow_flavor.json not found. Run init first.`

You're in the wrong directory, or you haven't run `init` yet.

### `❌ flow: missing required field "mode" in profile "staging"`

A profile in `.flow_deploy.json` is missing one of `mode`, `provider`, or
`platform`. See [Profiles](/config/deploy#profiles).

## Flutter / Dart

### `flow flavor build` exits non-zero with Flutter output

`flow` doesn't intercept Flutter build errors. Read the **flutter output
above** the `flow` exit line. The first line of `flow flavor build`'s output
is the literal `flutter build …` command — copy and run it yourself to
reproduce the failure without `flow` in the way.

### `Error: AppConfig is not defined`

You imported `package:.../app_config.dart` but haven't generated it.
Run `flow flavor init --from .flow_flavor.json`.

### Hot reload doesn't pick up new `--dart-define` values

`--dart-define` is compile-time. Stop the app and run `flow flavor run` again
after changing values in `.flow_flavor.json`.

## Android

### `Gradle: applicationId must be specified`

Your `android/app/build.gradle` lost its `applicationId` block. Restore it
from version control, or run [`flow flavor reset`](/flavor/reset) + re-init.

### `Could not find any matches for productFlavor 'dev'`

The Gradle product flavors block was hand-edited and removed the `dev`
entry. Re-run `flow flavor init --from .flow_flavor.json` to regenerate.

### Fastlane: `Package "com.acme.app.staging" not found`

Google Play has no listing for that package name. Either:

- Create the app in Play Console under that package name, **or**
- Fix `android.package_name` to match an existing listing.

### Fastlane: HTTP 401 / Authentication failure

The Google Play service account doesn't have **Release Manager** permission,
or the JSON key path is wrong. See [Where to get values → Google
Play](/config/where-to-get-values#google-play).

## iOS

### `Xcode build done. … xcodebuild: error: Scheme "staging" is not currently configured`

The Xcode scheme was deleted, or the scheme exists but isn't shared. Run
`flow flavor init --from .flow_flavor.json` to regenerate. If you committed
the project, also ensure `ios/Runner.xcodeproj/xcshareddata/xcschemes/*` is
under version control.

### Fastlane: `pilot: Could not find provisioning profile`

Code-signing problem (not a `flow` problem). Open Xcode → select the
flavor's scheme → Signing & Capabilities → fix the team / provisioning
profile. Then re-run with `--skip-build` so the rebuild uses the fixed
signing.

### Fastlane: `pilot: Authentication failed`

The `.p8` API key is invalid, the `key_id` / `issuer_id` don't match, or
the key was revoked. Regenerate via App Store Connect → Users and Access →
Keys.

### TestFlight: build stuck in "Processing" for >1 hour

Apple-side problem; not a `flow` issue. Submit a feedback report via App
Store Connect, then `flow deploy version --build` and upload again.

## Firebase

### `flutterfire: Firebase project "acme-app-dev" not found`

The project ID in `.flow_flavor.json` doesn't match any project you have
access to. Check Firebase Console for the exact slug (not the display name).

### `flutterfire: command not found`

```bash
dart pub global activate flutterfire_cli
```

Then ensure `~/.pub-cache/bin` is in your `PATH`.

### `firebase: command not found`

```bash
npm install -g firebase-tools
firebase login
```

### Firebase App Distribution: `HTTP 401 (UNAUTHENTICATED)`

The Firebase CLI session expired (or you're running in CI). Either:

```bash
firebase login                              # interactive
# or for CI:
firebase login:ci                           # prints FIREBASE_TOKEN
export FIREBASE_TOKEN=<token>               # then re-run flow
```

## TestFlight / external testing

### `Missing testflight.beta_app_review_info`

You set `enable_external_testing: true` but the `beta_app_review_info`
block is missing. Either complete the block (see [`.flow_deploy.json` →
ios.testflight](/config/deploy#iostestflight)) or switch back to internal
testing.

### "Build available to testers" never fires

For internal testers: ensure they're added to your App Store Connect team
with TestFlight access (Developer / App Manager / Marketing roles).

For external testers in a group with a public link: ensure the public link
toggle in App Store Connect → TestFlight → group settings is enabled.

## Versioning

### `Apple: build number X is already in use`

A previous upload used the same `+N` build number. Bump it:

```bash
flow deploy version --build
flow deploy update -p ios       # rebuild + reupload
```

### `Google Play: VersionCode X has already been used`

Same idea on Android — bump the build number and reupload.

### `flow: cannot parse version "1.4.2-rc.1+87"`

Pre-release tags aren't supported. Strip the tag.

## "Nothing happens" / silent failures

If a `flow` command appears to do nothing and exits 0, run with verbose
output (currently not exposed as a flag — but you can prefix with `bash
-x` if you suspect a wrapper script issue). For most "silent" cases, the
fix is to check whether the relevant config file exists and is at the
project root.

```bash
ls -la .flow_flavor.json .flow_deploy.json pubspec.yaml
```

## When all else fails

1. Run `flow --version` and confirm you're on a recent version.
2. Run the underlying tool directly (`flutter`, `fastlane`, `firebase`,
   `flutterfire`) with the same arguments `flow` would have used — the
   first line of `flow`'s output usually shows them.
3. Open an issue at
   [https://github.com/loqmanali/flow/issues](https://github.com/loqmanali/flow/issues)
   with the full command, the full output, and your `flow --version`.
