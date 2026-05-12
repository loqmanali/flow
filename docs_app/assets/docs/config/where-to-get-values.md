# Where to get values

A consolidated lookup table for every credential, ID, and path that
`.flow_flavor.json` and `.flow_deploy.json` ask for. Cross-referenced from
the individual field docs.

## App Store Connect

You'll create one API key per team; the same key powers all your apps.

### `ios.app_store_connect.key_id`, `issuer_id`, `key_filepath`

1. Open [App Store Connect](https://appstoreconnect.apple.com).
2. **Users and Access** (top nav) → click the **Keys** tab under
   "Integrations".
3. Click the **+** button to generate a new key.
4. Name it (e.g. "flow-ci"), set role to **App Manager**, click **Generate**.
5. The page now shows:
   - **Issuer ID** at the top — paste into `issuer_id`.
   - Your new key in the table with a **Key ID** column — paste into `key_id`.
6. Click **Download API Key** in the new row's "Actions". Save the `.p8` to
   `secrets/AuthKey_<key_id>.p8`. Set `key_filepath` to that path.

:::danger One download only
Apple lets you download the `.p8` exactly once. If you lose it, revoke the
key and create a new one.
:::

### `ios.app_identifier`

For each app/flavor:

- **Existing app**: open Xcode → select the **Runner** target → **Signing &
  Capabilities** tab → copy the **Bundle Identifier** value.
- **New flavor**: if `use_suffix: true` in `.flow_flavor.json`, the
  identifier is `<base>.<flavor>` (e.g. `com.acme.app.staging`).

Make sure the identifier exists in App Store Connect → **Apps** **before**
running an upload — `flow` won't create it for you.

## Google Play

### `android.json_key_path`

1. Open [Google Play Console](https://play.google.com/console).
2. **Setup** → **API access** (left sidebar).
3. **Choose a project to link** — pick or create a Google Cloud project.
4. Scroll to **Service accounts** → **Create new service account**. Google
   redirects you to Google Cloud Console.
5. Name it (e.g. `flow-uploader`), click **Create and Continue**, **Done**.
6. Back in Cloud Console → the new service account row → **Keys** → **Add
   key** → **JSON**. The file downloads.
7. Save it to `secrets/google-play-service-account.json`. Set
   `json_key_path` to that path.
8. Back in Play Console → **API access** → find the new service account →
   **Grant access** → set **App permissions** to "Release manager", click
   **Invite user** then **Send invitation**.

:::warn Permissions matter
Without **Release Manager** permission the service account can authenticate
but every upload fails with HTTP 401. Re-check this step if you see auth
errors.
:::

### `android.package_name`

This is the Android `applicationId`, not the Java package.

- **Non-flavored app**: open `android/app/build.gradle.kts` (or
  `build.gradle`), copy `applicationId`.
- **Flavored app with `use_suffix: true`**: the production flavor uses the
  base ID; non-production flavors append `.<flavor>`. Find the exact value by
  running:

  ```bash
  cd android && ./gradlew :app:printApplicationId
  ```

  or grep `android/app/build.gradle` for `applicationId`.

Whatever you put here **must exactly match** what Gradle generates — Play
Console matches uploads to listings by `applicationId`.

## Firebase

### `firebase.projects.<flavor>` (in `.flow_flavor.json`)

1. Open [Firebase Console](https://console.firebase.google.com).
2. The list view shows every project. The **Project ID** is the slug under
   each card (not the display name).
3. If you don't have one per flavor yet, click **Add project**, follow the
   wizard, then copy the resulting Project ID.

### `firebase_app_distribution.app_id` (in `.flow_deploy.json`)

1. In Firebase Console, open the project for the flavor you're configuring.
2. ⚙️ → **Project settings** → **General** tab.
3. Scroll to "Your apps". Each registered Android / iOS app has an **App ID**
   like `1:1234567890:android:abc123def456`.
4. Copy the one matching the platform you're configuring.

If the platform isn't registered yet:

- Click **Add app** in the same panel.
- Pick Android or iOS.
- Enter the bundle ID / application ID exactly as it appears in
  `android.package_name` / `ios.app_identifier`.
- Skip the SDK setup steps — `flow flavor firebase` handles that for you.
- Once registered, the App ID appears in the list.

### `firebase_app_distribution.groups`

1. Firebase Console → the project → **App Distribution** (left sidebar).
2. If the panel says "Get started", click through to enable App Distribution
   for the app.
3. **Testers & Groups** tab → **Add group**. Choose an alias (e.g.
   `qa-team`); this alias is what you put in `groups`.
4. Add testers to the group either inline or by uploading a CSV.

## Localization codes

### `changelog` keys

Both `android.changelog` and `ios.changelog` use the locale codes the
respective console expects.

- **Android (Play Console)**: BCP-47 with a country suffix. Common values:
  `en-US`, `en-GB`, `ar-SA`, `fr-FR`, `de-DE`, `ja-JP`, `pt-BR`, `es-ES`.
  The full list is in [Play Console → Store
  listings](https://play.google.com/console/about/manage/store-listings/).
- **iOS (App Store Connect)**: a fixed set. Common values are the same as
  Android. See [App Store Connect Help → App information →
  Languages](https://developer.apple.com/app-store-connect/) for the full
  table.

A locale that's defined in the changelog but **not enabled** for the app in
the console will be silently ignored by Fastlane.

## TestFlight contact info

### `ios.testflight.beta_app_review_info`

Apple uses this to contact you about external-testing reviews. It does not
have to be a real human — most teams set up a shared `appstore-review@`
mailbox.

- `contact_email`, `contact_first_name`, `contact_last_name`, `contact_phone`
  are visible only to Apple, not to testers.
- `notes` is free-form text shown to App Review (e.g. "Demo account requires
  invite link emailed to dev@acme.com").

## .gitignore checklist

Make sure your `.gitignore` has at least:

```
# flow secrets
secrets/

# Firebase config files (if you commit `firebase_options_*` they're fine, but
# the per-flavor google-services.json + GoogleService-Info.plist should
# usually stay in the repo unless they leak per-environment URLs you don't
# want public).
```

The two config files themselves (`.flow_flavor.json` and `.flow_deploy.json`)
are safe to commit — they reference paths to credentials, not the credentials
themselves.
