# TestFlight beta

How to ship a TestFlight build, both internal (no review) and external
(reviewable, but open to anyone with a link).

## Two flavors of TestFlight

| | Internal testing | External testing |
|---|---|---|
| Audience | App Store Connect team members | Anyone you invite (or anyone with the public link) |
| App Review required | No | Yes, but typically <24h |
| Max testers | 100 | 10,000 |
| `enable_external_testing` | `false` | `true` |
| Required `testflight.*` config | _just the API key_ | full `beta_app_review_info` |

## Internal testing (the easy path)

`.flow_deploy.json`:

```json
"ios": {
  "app_store_connect": {
    "key_id": "ABCD123456",
    "issuer_id": "12345678-1234-1234-1234-123456789012",
    "key_filepath": "secrets/AuthKey_ABCD123456.p8"
  },
  "testflight": {
    "enable_external_testing": false
  }
}
```

That's it. Run:

```bash
flow deploy beta -p ios
```

```terminal
$ flow deploy beta -p ios
✓ Loaded .flow_deploy.json
…
→ flutter build ipa --release …
✓ Built build/ios/ipa/Acme Staging.ipa

→ fastlane ios beta
  → pilot: uploading to App Store Connect…
  ✓ Build 87 uploaded
  ✓ Processing started

Done. The build will appear under TestFlight → iOS Builds in 5-15 minutes
with status "Ready to Submit" — internal testers will receive a TestFlight
notification automatically.
```

To add internal testers: App Store Connect → **Users and Access** → invite
people with **App Manager**, **Developer**, or **Marketing** roles. They'll
get TestFlight invitations the moment a build finishes processing.

## External testing

External testing means **anyone with the TestFlight link** can install your
build. The first build under a given marketing version (1.0.0, 1.1.0, etc.)
must pass App Review — typically 24 hours but sometimes faster.

### `.flow_deploy.json`

```json
"ios": {
  "app_store_connect": {
    "key_id": "ABCD123456",
    "issuer_id": "12345678-1234-1234-1234-123456789012",
    "key_filepath": "secrets/AuthKey_ABCD123456.p8"
  },
  "testflight": {
    "enable_external_testing": true,
    "groups": "Public Beta",
    "beta_app_feedback_email": "feedback@acme.com",
    "beta_app_review_info": {
      "contact_email": "review@acme.com",
      "contact_first_name": "Acme",
      "contact_last_name": "Reviewer",
      "contact_phone": "+15551234567",
      "demo_account_required": false,
      "demo_account_name": "",
      "demo_account_password": "",
      "notes": "No login required to evaluate the build."
    }
  }
}
```

### Create the group first

In App Store Connect → your app → **TestFlight** → **External Testing** →
**Add Group**. Name the group "Public Beta" (matching `groups` above).

If you want a **public link** for the group, toggle "Public Link" inside the
group settings. Apple gives you a URL that any tester can open to join.

### Demo account fields

If your app requires login to evaluate, set:

```json
"demo_account_required": true,
"demo_account_name": "demo@acme.com",
"demo_account_password": "AcmeDemo!2026"
```

This information is passed to the reviewer and shared with Apple — treat
the credentials as semi-public.

### Run the upload

```bash
flow deploy beta -p ios
```

The build uploads, then `pilot` automatically submits it to external testing
because `enable_external_testing: true`. You'll see status changes in App
Store Connect:

| Status | Meaning |
|---|---|
| **Processing** | Apple is preparing the binary (5-15 min) |
| **Waiting for Review** | Submitted to Beta App Review |
| **In Review** | Reviewer is evaluating |
| **Ready to Submit** | (for the internal flow; external goes straight to "Approved") |
| **Approved** | Live — external testers can install |

### Subsequent builds

Once you've cleared review for marketing version `1.0.0`, every subsequent
build with the same marketing version (`1.0.0+88`, `1.0.0+89`, …) skips
review and goes live immediately. **Bumping the marketing version** (to
`1.0.1` or `1.1.0`) triggers a new review.

## Walkthrough — external testing run

```terminal
$ flow deploy beta -p ios
✓ Loaded .flow_deploy.json
ℹ enable_external_testing=true → groups: "Public Beta"

→ flutter build ipa --release …
✓ Built build/ios/ipa/Acme.ipa

→ fastlane ios beta
  → pilot: uploading
  ✓ Build 88 uploaded
  → pilot: distribute_external=true → submitting for beta review
  ✓ Beta review submitted

Done. Expect status updates within 24 hours.
```

## Common errors

```terminal
[E] Missing testflight.groups in .flow_deploy.json (required for external testing)
[E] Missing testflight.beta_app_feedback_email in .flow_deploy.json (required for external testing)
[E] Missing testflight.beta_app_review_info in .flow_deploy.json (required for external testing)
exit 1
```
You set `enable_external_testing: true` without filling in the rest. Either
go back to internal-only, or complete the review info.

```terminal
Fastlane error: pilot — group "Public Beta" not found
   Available groups: Internal Team
```
Create the group in App Store Connect first.

```terminal
Apple: Beta App Review rejection
   Reason: Crashes on launch on iPhone 14, iOS 18.4
```
This is rare with `flow` because the IPA is built locally first. If it
happens, the build genuinely crashed for the reviewer — usually a missing
release-mode plugin permission or signing issue. Debug locally with
`flow flavor run staging release` on a physical device.

:::tip Don't enable external testing until you're ready
External testing means real users see your build. Until your QA team has
signed off internally, keep `enable_external_testing: false`. Toggle to
`true` only when you're confident the build is acceptable.
:::
