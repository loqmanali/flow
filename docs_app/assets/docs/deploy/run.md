# `flow deploy run`

Invoke a named profile from `.flow_deploy.json`. A profile bundles
`mode`, `provider`, `platform`, and (optionally) `build` / per-platform
overrides into a single name.

## Synopsis

```bash
flow deploy run <profile> [flags…]
```

Or via the top-level shortcut:

```bash
flow <profile> [flags…]
```

`flow` recognizes the special top-level commands (`flavor`, `deploy`,
`help`); anything else is forwarded to `flow deploy run`. So `flow staging`
is exactly `flow deploy run staging`.

## Arguments

| Position | Description |
|---|---|
| `<profile>` | A key from the `profiles` object in `.flow_deploy.json`. Required. |

The same flags accepted by [`flow deploy beta`](/deploy/beta) and
[`flow deploy update`](/deploy/update) are accepted here, and they
override the profile's values.

## Profile resolution order

For each field (`flavor`, `target`, `platform`, `provider`, etc.):

1. CLI flag (highest priority)
2. The profile's value
3. The top-level `.flow_deploy.json` value
4. Hard-coded default (lowest priority)

## Walkthrough — using a profile shortcut

Given this profile in `.flow_deploy.json`:

```json
"staging": {
  "mode": "beta",
  "provider": "mixed",
  "platform": "all",
  "build": { "flavor": "staging", "target": "lib/main_staging.dart" },
  "android": { "package_name": "com.acme.app.staging" },
  "ios": { "app_identifier": "com.acme.app.staging" }
}
```

The shortcut command:

```bash
flow staging
```

Expands to:

```terminal
$ flow staging
✓ Loaded .flow_deploy.json
ℹ Deployment profile: staging
ℹ Deployment provider: mixed (android→firebase, ios→fastlane)
ℹ Platform: all
ℹ Build flavor: staging
ℹ Build target: lib/main_staging.dart

→ flutter build appbundle --release --flavor staging \
    --target lib/main_staging.dart …
✓ Built …app-staging-release.aab

→ flutter build ipa --release --flavor staging \
    --target lib/main_staging.dart …
✓ Built …Acme Staging.ipa

→ firebase appdistribution:distribute …
✓ Uploaded to Firebase App Distribution

→ fastlane ios beta
  ✓ pilot: build uploaded

Done.
```

## Walkthrough — overriding profile values

Run the staging profile but only against iOS:

```bash
flow staging --platform ios
```

Or run it without rebuilding (reuse the existing IPA):

```bash
flow staging --platform ios --skip-build
```

## Walkthrough — explicit form

If a profile name collides with a future `flow` top-level command, fall back
to the explicit form:

```bash
flow deploy run staging
flow deploy run staging --platform ios
```

## Common errors

```terminal
❌ flow: unknown deployment profile "stagin"
   Available profiles: dev, staging, production
```

```terminal
❌ flow: no profiles configured in .flow_deploy.json
   Run `flow deploy init` and choose a template that includes profiles, or
   add a "profiles" block manually.
```

```terminal
❌ flow: missing required field "mode" in profile "staging"
```

:::tip Profile names = release-channel names
Naming profiles after channels (`dev`, `staging`, `production`) keeps CI
configuration tidy: each branch's CI step just runs `flow $CHANNEL` and
the profile maps that to the right combination of provider, platform, and
build settings.
:::
