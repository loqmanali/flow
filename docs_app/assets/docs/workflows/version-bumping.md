# Version bumping

Patterns for keeping `pubspec.yaml` versions consistent across your team
and CI — including release branches, hotfixes, and re-uploads.

## The default

`.flow_deploy.json` ships with:

```json
{
  "skip_version_increment": true
}
```

This means **no command automatically bumps the version** unless you ask.
Bumps happen explicitly via:

- `flow deploy version --major/--minor/--patch/--build`, or
- `flow deploy beta --increment-version` / `flow deploy update --increment-version`.

The reason for this default: most teams want explicit control over what
version goes to production. Auto-bump-on-deploy is convenient but it
couples version policy to deploy timing.

## Pattern 1 — manual bumps per release

Best for teams using a release-branch workflow.

```bash
# On the release branch
flow deploy version --minor    # 1.4.2+87 → 1.5.0+88
git commit -am "release 1.5.0"
git tag v1.5.0

# Ship the build
flow staging                    # uses 1.5.0+88
# QA approves...
flow deploy update             # ships 1.5.0+88 to App Store / Play
```

For patch hotfixes off a release branch:

```bash
flow deploy version --patch    # 1.5.0+88 → 1.5.1+89
git commit -am "release 1.5.1"
flow deploy update -p ios      # iOS hotfix only
```

## Pattern 2 — auto-bump on every deploy

Best for teams shipping continuously, where each deploy genuinely
represents a new version.

Set in `.flow_deploy.json`:

```json
{
  "skip_version_increment": false
}
```

Now every `flow deploy beta` / `update` runs `flow deploy version --patch`
before building. To override per-run:

```bash
flow deploy beta --skip-version-increment   # don't bump this time
```

## Pattern 3 — build number bumps only, semver manual

Best when semver is a marketing decision (set by humans) but build numbers
must always be unique.

`.flow_deploy.json`:

```json
{
  "skip_version_increment": true
}
```

In CI, before invoking `flow deploy`:

```bash
flow deploy version --build    # only bumps the +N suffix
flow staging
```

This keeps the marketing version stable while every CI run gets a unique
build number, which is required for TestFlight / Play uploads.

## Pattern 4 — bumping for CI retries

Sometimes Fastlane fails after a successful upload (e.g. validation timeout),
and the next attempt is rejected because the build number is taken.

```bash
flow deploy version --build    # 1.5.0+88 → 1.5.0+89
flow deploy update -p ios --skip-build  # reuse the existing IPA? No — build number changed, need fresh IPA
```

Actually for this case **rebuild after bumping** — the build number is
embedded in the IPA's `CFBundleVersion`:

```bash
flow deploy version --build
flow deploy update -p ios      # build + upload with new number
```

## The cardinal rule

> Build numbers (`+N`) must monotonically increase per platform/marketing
> version, forever.

Apple and Google both reject uploads with build numbers ≤ what they've
already seen.

If you ever lose track:

- **iOS**: check App Store Connect → your app → TestFlight → iOS Builds.
  The highest build number listed is what you must beat.
- **Android**: check Google Play Console → your app → Release management.
  Same idea.

Then in `pubspec.yaml`:

```bash
flow deploy version --set 1.5.0+91   # whatever beats the highest you saw
```

## Walkthrough — coordinated minor release

A real-world flow when shipping `1.5.0`:

```terminal
$ git checkout -b release/1.5.0
$ flow deploy version --minor
ℹ pubspec.yaml: 1.4.7+103 → 1.5.0+104
✓ Updated pubspec.yaml
$ git commit -am "chore(release): 1.5.0"

$ flow staging                  # internal QA: 1.5.0+104 to TestFlight + FAD
✓ Built and uploaded both platforms
✓ Done.

# After QA approves:
$ flow deploy update            # publish 1.5.0+104 to stores
✓ Submitted to App Review
✓ Submitted to Play production

$ git tag v1.5.0
$ git push --tags
```

## Common pitfalls

### Race between two developers

Two developers shipping at the same time from different branches both
bump the build number, then merge — one of them has a stale value.

Mitigation: keep the bump in CI only, and pull the latest `pubspec.yaml`
state from a version-tracking source rather than the working tree. For
small teams, the manual pattern (bump on the release branch only) avoids
this entirely.

### Off-by-one in `--set`

Setting an exact version is the only way to recover from a desync — but it's
also the easiest way to ship the wrong version:

```bash
flow deploy version --set 1.5.0+1   # only correct if 1.5.0 hasn't shipped yet
```

If `1.5.0` ever uploaded a build, the next `+N` must beat the highest
recorded. There's no automation that catches this — eyeball the store
dashboards before setting.

:::tip Combine with semver tagging
If you tag releases (`v1.5.0`) at the same commit where `flow deploy
version --minor` updates the pubspec, `git describe` always shows the exact
version of any build. Drop this into your `AppConfig` via `--dart-define`
to surface the version + commit in your app's About screen.
:::
