# `flow deploy`

Build and ship to TestFlight, the App Store, Google Play, or Firebase App
Distribution. Every subcommand reads `.flow_deploy.json`.

## Subcommand index

| Command | What it does |
|---|---|
| [`init`](/deploy/init) | Interactive config wizard → writes `.flow_deploy.json` |
| [`beta`](/deploy/beta) | Build and upload for beta testing (TestFlight / FAD) |
| [`update`](/deploy/update) | Build and submit app updates (App Store / Play) |
| [`version`](/deploy/version) | Show or change `pubspec.yaml` version + build number |
| [`run`](/deploy/run) | Invoke a named profile from `.flow_deploy.json` |

## The two modes

| Mode | Pipeline |
|---|---|
| **beta** | Build → upload for testing → done. The upload is private to internal testers (no review) by default, or to an external test group if you've configured TestFlight external testing or Firebase tester groups. |
| **update** | Build → upload to store → submit for review → request automatic release on approval. Used to publish a new public version. |

You pick the mode via the subcommand (`beta` vs `update`) or via the `mode`
field in a profile.

## The three providers

| Provider | Used for | Requires |
|---|---|---|
| `fastlane` | TestFlight, App Store, Google Play | Fastlane installed; `app_store_connect.*` / `json_key_path` filled in |
| `firebase` | Firebase App Distribution | Firebase CLI installed; `firebase_app_distribution.*` filled in |
| `mixed` | Android via Firebase + iOS via TestFlight in one call | Both of the above |

`mixed` requires `platform: all` — it's pointless to ask for "Android via
Firebase + iOS via Fastlane" on a single platform.

## Top-level options shared by `beta` and `update`

| Flag | Short | Default | Description |
|---|---|---|---|
| `--platform <ios\|android>` | `-p` | both | Limit the run to a single platform. |
| `--provider <fastlane\|firebase\|mixed>` | `-r` | _(prompted)_ | Override the provider. |
| `--flavor <name>` | `-f` | _(from profile or config)_ | Flutter `--flavor`. |
| `--target <path>` | `-t` | _(from profile or config)_ | Flutter `--target`. |
| `--skip-build` | `-s` | `false` | Skip `flutter build` and use existing artifacts. |
| `--increment-version` | — | `false` | Bump patch + build number before building. |
| `--skip-version-increment` | — | `false` | Force the version to stay unchanged for this run. |

Both increment flags are mutually exclusive — using both at once fails fast.

## How profiles fit in

A **profile** is a saved combination of `mode`, `provider`, `platform`, and
build settings. Profiles let you say `flow deploy run staging` instead of
`flow deploy beta --provider mixed --platform all --flavor staging --target lib/main_staging.dart`.

You can also use the top-level shortcut `flow staging` — `flow` matches the
first argument against known top-level commands, and if it doesn't match,
forwards it as a profile name to `flow deploy run`.

See [`flow deploy run`](/deploy/run) and the [Profiles section of
`.flow_deploy.json`](/config/deploy#profiles).

## How a deploy executes (at a glance)

1. Load `.flow_deploy.json`; bail out fast if required fields for the chosen
   provider/mode are missing.
2. (Unless `--skip-build`) Run `flow flavor build <target> <flavor>` to
   produce the artifact (`.aab` for Android, `.ipa` for iOS).
3. (Unless `--skip-version-increment` or `skip_version_increment: true`)
   Bump the pubspec version.
4. Hand the artifact to Fastlane or the Firebase CLI.
5. Wait for the upload to complete; surface any errors back to your terminal.
