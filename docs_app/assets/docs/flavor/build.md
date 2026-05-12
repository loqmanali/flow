# `flow flavor build`

A standardized wrapper around `flutter build` that handles `--flavor`,
`--target`, and `--dart-define` for you.

## Synopsis

```bash
flow flavor build [<target>] [<flavor>]
```

## Arguments

| Position | Description |
|---|---|
| `<target>` | Optional. The Flutter build target: `apk` / `appbundle` / `ipa` / `ios` / `web` / `macos` / `windows` / `linux`. Prompted if omitted. |
| `<flavor>` | Optional. The flavor name. Prompted if omitted. |

## What it does

Same argument-resolution logic as [`flow flavor run`](/flavor/run): loads
the config, resolves the entry point, expands `fields` × `values` into
`--dart-define` flags, then shells out to `flutter build <target>`.

## Walkthrough — Android AAB

```terminal
$ flow flavor build appbundle production
→ flutter build appbundle \
    --release \
    --flavor production \
    --target lib/main_production.dart \
    --dart-define=FLAVOR=production \
    --dart-define=baseUrl=https://api.acme.com \
    --dart-define=debug=false
Running Gradle task 'bundleProductionRelease'...
Built build/app/outputs/bundle/productionRelease/app-production-release.aab (24.3MB)

Output: build/app/outputs/bundle/productionRelease/app-production-release.aab
```

## Walkthrough — iOS IPA

```terminal
$ flow flavor build ipa staging
→ flutter build ipa \
    --release \
    --flavor staging \
    --target lib/main_staging.dart \
    --dart-define=FLAVOR=staging \
    --dart-define=baseUrl=https://stage.api.acme.com \
    --dart-define=debug=true
Building com.acme.app.staging for device (ios-release)...
Archiving com.acme.app.staging...
Running Xcode build...                                            5.9s
Built /Users/.../build/ios/ipa/Acme Staging.ipa (52.4MB)
```

## Walkthrough — interactive

```terminal
$ flow flavor build
? Build target: › apk / appbundle / ipa / ios / web / macos
? Pick a flavor: › dev / stage / production
…
```

## Build mode

`flutter build` defaults to `release` — `flow flavor build` follows the same
default and does not currently expose `--debug` / `--profile`. If you need
those, invoke `flutter build` directly with the same argument list that
`flow` would have produced (the first line of the output is a literal copy
of the flutter command, so you can prepend `--debug` and re-run yourself).

## Common errors

```terminal
❌ flow: unknown build target "amazing"
   Allowed: apk, appbundle, ipa, ios, web, macos, windows, linux
```

```terminal
❌ flow: build failed (flutter exit code 1)
   See the flutter output above for the underlying error.
```

`flow` does **not** intercept Flutter build failures — its job stops at
preparing the arguments. Debug build errors using `flutter`'s own output.

:::tip CI builds
For CI, prefer the explicit form `flow flavor build appbundle production`
(no prompts). Combine with `--skip-version-increment` on
[`flow deploy`](/deploy/beta) to keep `pubspec.yaml` stable across reruns.
:::
