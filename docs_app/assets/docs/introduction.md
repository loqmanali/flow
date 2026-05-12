# Introduction

**flow** is a command-line tool for Flutter teams who are tired of doing the same setup work on every project. One binary handles two recurring chores:

1. **Build flavors** — Android `productFlavors`, iOS schemes + `.xcconfig`, `--dart-define` injection, VS Code launch configurations, and per-flavor Firebase wiring.
2. **Deployment** — building release artifacts, bumping versions, and shipping them to TestFlight, the App Store, Google Play, or Firebase App Distribution.

Both live under a single executable: `flow`.

## Why it exists

In a typical Flutter project, the path from "I have a working app" to "users can install the staging build on TestFlight" involves dozens of manual steps spread across `build.gradle`, Xcode project files, Fastlane configuration, App Store Connect API keys, Firebase distribution IDs, and shell scripts. Most teams rebuild this scaffolding from scratch every project.

`flow` codifies the common path. The opinions are deliberate:

- One source of truth per concern: `.flow_flavor.json` for build flavors, `.flow_deploy.json` for deployment.
- Interactive wizards for first-time setup, idempotent commands for everyday work.
- Generated artifacts (Fastlane files, `.xcconfig`, scripts) are reproducible — running the same command twice never breaks state.

:::tip Production-friendly defaults
Every generated artifact targets real-world store delivery. Internal-testing-only fields like `enable_external_testing` default to `false`, so you can ship a private TestFlight build without ever touching review information.
:::

## Two command groups

| Group | Purpose | Config file |
|---|---|---|
| `flow flavor` | Configure and maintain Flutter build flavors | `.flow_flavor.json` |
| `flow deploy` | Build and ship to stores or beta channels | `.flow_deploy.json` |

You can adopt either independently. A project with no flavors only needs `.flow_deploy.json`; a library that never ships to stores only needs `.flow_flavor.json`.

## What it does not do

- It does **not** create your app on App Store Connect or Google Play. Both stores require manual app creation through their dashboards before any automation can take over.
- It does **not** replace your CI pipeline. `flow` is the unit your CI invokes; it doesn't manage runners, secrets, or webhooks itself.
- It does **not** edit your application source code. Generated files (e.g. `AppConfig`) live at paths you configure.

## Where to next

- **Just trying it out?** Start with [Installation](/installation) → [Quick start](/quick-start).
- **Wiring up an existing project?** Read [`.flow_flavor.json`](/config/flavor) and [`.flow_deploy.json`](/config/deploy) first, then jump to [First-time setup](/workflows/first-time-setup).
- **Looking for a single command?** The sidebar lists every command under `flow flavor` and `flow deploy`.
