# `flow deploy init`

Generates `.flow_deploy.json` with placeholders for everything you need to
fill in. Picks a template based on which provider(s) you plan to use.

## Synopsis

```bash
flow deploy init
```

## Walkthrough — both providers, flavored

```terminal
$ flow deploy init
? Provider template:
  › Both (fastlane + firebase)
    Fastlane only (TestFlight / App Store / Play)
    Firebase App Distribution only
? Include flavor configuration? › Yes
✓ Wrote .flow_deploy.json (combined template, flavor-ready)

Next steps:
  1. Open .flow_deploy.json
  2. Fill in fields marked "(Required)"
  3. Add your credentials under android.json_key_path and
     ios.app_store_connect.*
  4. Run `flow deploy beta -p ios` for a smoke test
```

## What the picker decides

| Provider template | Top-level keys generated |
|---|---|
| Both | `android.json_key_path`, `android.firebase_app_distribution`, `ios.app_store_connect`, `ios.testflight`, `ios.firebase_app_distribution` |
| Fastlane only | `android.json_key_path`, `ios.app_store_connect`, `ios.testflight` |
| Firebase only | `android.firebase_app_distribution`, `ios.firebase_app_distribution` (no Fastlane keys) |

When you answer "Yes" to flavor configuration, two extra things happen:

1. Each platform block gets `package_name` / `app_identifier` placeholders.
2. A top-level `profiles` object is added with `dev`, `staging`, and
   `production` pre-wired to sensible defaults.

## Default profile layout

For "Both + flavor configuration":

```json
"profiles": {
  "dev":        { "mode": "beta",   "provider": "firebase", "platform": "all",
                  "build": { "flavor": "dev",        "target": "lib/main_dev.dart" } },
  "staging":    { "mode": "beta",   "provider": "firebase", "platform": "all",
                  "build": { "flavor": "staging",    "target": "lib/main_staging.dart" } },
  "production": { "mode": "update", "provider": "fastlane", "platform": "all",
                  "build": { "flavor": "production", "target": "lib/main_production.dart" } }
}
```

Adjust to taste — for instance, you might want `staging` to use `mixed` so
iOS testers get TestFlight while Android gets Firebase.

## Overwrite behavior

If `.flow_deploy.json` already exists, `init` will refuse to overwrite it
without confirmation:

```terminal
$ flow deploy init
⚠ .flow_deploy.json already exists.
? Overwrite? › No
Aborted. No changes made.
exit 0
```

Pick "Yes" only if you really want to start over — the existing file is
deleted.

## What you'll need to fill in after

Look for the literal string `(Required)` in the generated file. Each one is
a placeholder; see [Where to get values](/config/where-to-get-values) for
exactly how to obtain each credential.

Common fields:

- `android.json_key_path` — path to Google Play service account JSON
- `ios.app_store_connect.{key_id, issuer_id, key_filepath}` — App Store
  Connect API key trio
- `ios.firebase_app_distribution.app_id` / `android.firebase_app_distribution.app_id`
  — Firebase app IDs

For external TestFlight testing only:

- `ios.testflight.enable_external_testing: true`
- `ios.testflight.groups`
- `ios.testflight.beta_app_feedback_email`
- `ios.testflight.beta_app_review_info.*`

## Common errors

```terminal
❌ flow: unable to write .flow_deploy.json: permission denied
```
The project directory isn't writable. Check ownership.

:::tip Skip the prompts in CI
There's no `--from` flag for `flow deploy init`. For automated bootstrapping,
commit a hand-authored `.flow_deploy.json` to your repo template and skip
`init` entirely — `flow deploy beta` reads whatever's at the file path.
:::
