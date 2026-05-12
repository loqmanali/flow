# `flow flavor migrate`

Updates an older `.flow_flavor.json` to the current schema. Run this after
upgrading `flow` if you see schema validation errors.

## Synopsis

```bash
flow flavor migrate
```

## What it migrates

The current schema requires every entry in `flavors` to have a matching
entry in `values` for every key in `fields`. Older configs sometimes had
`fields` defined but no `values` block — `migrate` adds the missing entries
interactively.

It also normalizes the structure of `firebase.projects` so every flavor in
`flavors` has a corresponding project ID (placeholder strings are inserted
where missing; you'll be prompted to fill them).

## Walkthrough — adding missing `values`

```terminal
$ flow flavor migrate
✓ Loaded .flow_flavor.json (3 flavors, 2 AppConfig fields)
⚠ values.dev is missing key "maxRetries"
⚠ values.stage is missing key "maxRetries"
⚠ values.production is missing key "maxRetries"

? maxRetries (int) for dev: › 3
? maxRetries (int) for stage: › 3
? maxRetries (int) for production: › 5

✓ Updated .flow_flavor.json

💡 Tip: Run "flow flavor init --from .flow_flavor.json" now to synchronize
   your project with the new configuration.
```

## Walkthrough — nothing to migrate

```terminal
$ flow flavor migrate
✓ .flow_flavor.json is already on the current schema. Nothing to do.
```

## What `migrate` does **not** do

- It does **not** apply changes to the project (Android Gradle, Xcode,
  generated Dart). You must run `flow flavor init --from .flow_flavor.json`
  afterwards to propagate the updated config to platform files.
- It does **not** rename fields or migrate value types — if you renamed
  `apiUrl` to `baseUrl`, the migration won't pick that up. Edit
  `.flow_flavor.json` by hand for renames.
- It does **not** consult an external schema registry. It always migrates
  to whatever schema is current for the installed `flow` version.

## Common errors

```terminal
❌ flow: could not find or parse .flow_flavor.json
```
The file is missing or the JSON is malformed. Fix the syntax, then re-run.

```terminal
❌ flow: cannot migrate — production_flavor "qa" is not in flavors
```
A structural problem the migration can't repair automatically. Fix the
field manually.

:::tip Always re-init after migrate
After `migrate` updates the JSON, the generated Dart code and platform
files are still on the old schema. The reminder at the bottom of the
output (`💡 Tip: Run …`) is not optional — re-running `init --from
.flow_flavor.json` is required to fully apply the migration.
:::
