# `flow deploy version`

Show or change the version in `pubspec.yaml`. Works with or without
`.flow_deploy.json`.

## Synopsis

```bash
flow deploy version                # show current version
flow deploy version --major        # bump major
flow deploy version --minor        # bump minor
flow deploy version --patch        # bump patch
flow deploy version --build        # bump build number only
flow deploy version --set 2.0.0+1  # set exact value
```

## How Flutter versions look

A pubspec version has two parts separated by `+`:

```
1.4.2+87
└─┬─┘ └┬┘
  │    └─ build number (Android versionCode, iOS CFBundleVersion)
  └───── semver (Android versionName, iOS CFBundleShortVersionString)
```

`flow deploy version` always bumps the **build number** alongside the
semver change, except when `--build` is used (which bumps the build number
only).

## Behavior table

| Flag | Before | After |
|---|---|---|
| `--major` | `1.4.2+87` | `2.0.0+88` |
| `--minor` | `1.4.2+87` | `1.5.0+88` |
| `--patch` | `1.4.2+87` | `1.4.3+88` |
| `--build` | `1.4.2+87` | `1.4.2+88` |
| `--set 3.0.0+1` | `1.4.2+87` | `3.0.0+1` |

## Walkthrough — show current

```terminal
$ flow deploy version
ℹ pubspec.yaml: 1.4.2+87
```

## Walkthrough — bump patch

```terminal
$ flow deploy version --patch
ℹ pubspec.yaml: 1.4.2+87 → 1.4.3+88
✓ Updated pubspec.yaml
```

## Walkthrough — set explicit

```terminal
$ flow deploy version --set 2.0.0+1
ℹ pubspec.yaml: 1.4.3+88 → 2.0.0+1
✓ Updated pubspec.yaml
```

## Walkthrough — bump build only

Useful when re-uploading the same release for a Fastlane validation retry:

```terminal
$ flow deploy version --build
ℹ pubspec.yaml: 1.4.3+88 → 1.4.3+89
✓ Updated pubspec.yaml
```

## How it integrates with `beta` / `update`

By default, `flow deploy beta` and `flow deploy update` honor the
`skip_version_increment` field in `.flow_deploy.json` (`true` by default), so
they do **not** bump the version on every run.

Override per-run:

- `flow deploy beta --increment-version` — bumps patch + build before
  building.
- `flow deploy beta --skip-version-increment` — explicit no-bump (useful
  when `skip_version_increment` is `false` in the config but you want one
  exception).

The two flags are mutually exclusive — passing both fails fast.

## Common errors

```terminal
❌ flow: cannot parse version "1.4.2-rc.1+87" — only standard semver is supported
```
Pre-release tags like `-rc.1` aren't handled. Strip the tag, then re-run.

```terminal
❌ flow: --set requires a value in the form <semver>+<build>
   Got: "1.4.2"
```
Always pass both halves to `--set`.

```terminal
❌ flow: cannot find pubspec.yaml in current directory
   Are you at the project root?
```

:::tip Make sure CI runs `--build` between retries
If your CI uploads to TestFlight or Play and the first attempt times out,
the next run with the same build number will be rejected. Insert
`flow deploy version --build` between retries.
:::
