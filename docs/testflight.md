# Headless TestFlight releases

T2Do ships to TestFlight from GitHub Actions — no Xcode Organizer, no manual
signing, no 2FA. This doc covers the **one-time setup** and the
**per-release** flow.

- Workflow: [`.github/workflows/ios-testflight.yml`](../.github/workflows/ios-testflight.yml)
- fastlane lane: [`fastlane/Fastfile`](../fastlane/Fastfile) → `beta`

## How a release works

`fastlane beta` (run by the workflow) does:

1. `setup_ci` — creates a throwaway keychain on the runner.
2. Authenticates to App Store Connect with the **API key** (no Apple ID / 2FA).
3. `match (readonly)` — installs the distribution cert + App Store profiles
   (app **and** widget extension) from the private certs repo.
4. Computes the next build number = highest on TestFlight + 1.
5. Writes manual-signing settings (team, identity, per-target profile) into
   the project for the `TwoDo` and `TwoDoWidgets` targets — profiles can't go
   through `xcargs` because xcargs apply to every target.
6. `build_app` — archives the **Release** config, injecting the build number
   via `CURRENT_PROJECT_VERSION` at build time (no project edit, no
   commit-back).
7. `upload_to_testflight` — uploads the build.

`MARKETING_VERSION` (the user-facing `1.0`) is **not** automated — bump it in
Xcode (target → General → Version) when you want a new version string.

## Per-release flow

- **Manual:** Actions tab → *iOS TestFlight* → *Run workflow*.
- **On tag:** `git tag ios-v1.0.1 && git push origin ios-v1.0.1` — any tag
  matching `ios-v*` triggers a release.

That's it — the build appears in TestFlight a few minutes later.

## One-time setup

### 1. App Store Connect API key

App Store Connect → **Users and Access → Integrations → App Store Connect API**
→ generate a key with the **App Manager** role. Download the `AuthKey_XXXX.p8`
**immediately** (one-time download). Note the **Key ID** and **Issuer ID**.

(An existing team key already lives at `~/.appstoreconnect/private_keys/` on
the dev Mac — reuse it if it has the App Manager role.)

### 2. fastlane match certs repo

Create a **private** git repo (e.g. `<you>/twodo-certs`) to hold the encrypted
signing assets. Then, once, from the repo root on a Mac with the signing
account logged in:

```bash
bundle install
export MATCH_GIT_URL="https://github.com/<you>/twodo-certs.git"
export MATCH_PASSWORD="<choose-a-strong-passphrase>"   # remember this
bundle exec fastlane match appstore --readonly false
```

This creates the Apple **distribution certificate** + **App Store provisioning
profiles** for `com.kadeem.twodo` and `com.kadeem.twodo.widgets`, encrypts
them with `MATCH_PASSWORD`, and pushes them to the certs repo. CI only ever
reads them during releases (the Matchfile pins `readonly: true`).

> Profiles are snapshots of an App ID's capabilities. Both App IDs need their
> capabilities enabled in the developer portal **before** match generates
> profiles: `com.kadeem.twodo` needs iCloud/CloudKit, Push Notifications, and
> App Groups (`group.com.kadeem.twodo`); `com.kadeem.twodo.widgets` needs App
> Groups (same group).

### Adding a target or capability later

Match profiles go stale whenever a signable target is added or an App ID gains
a capability. To repair:

1. In the [developer portal](https://developer.apple.com/account/resources/identifiers/list),
   register any new App ID / App Group and enable the capability on the
   affected App IDs.
2. Add the new bundle id to `fastlane/Matchfile`, `ALL_IDENTIFIERS` and
   `SIGNED_TARGETS` in `fastlane/Fastfile`.
3. Regenerate profiles: Actions tab → *iOS Signing Sync* → *Run workflow*
   (runs `fastlane sync_signing`, i.e. `match --force` with write access —
   the `MATCH_GIT_BASIC_AUTHORIZATION` PAT must be able to **write** to the
   certs repo), or locally `bundle exec fastlane sync_signing` with the env
   vars below.

### 3. GitHub repository secrets

Settings → Secrets and variables → Actions → **New repository secret**:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | the API Key ID |
| `ASC_ISSUER_ID` | the API Issuer ID |
| `ASC_KEY_P8` | `base64 -i AuthKey_XXXX.p8` (the whole file, base64-encoded) |
| `MATCH_GIT_URL` | HTTPS URL of the certs repo |
| `MATCH_PASSWORD` | the passphrase chosen in step 2 |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `printf 'USER:PAT' \| base64` — a GitHub PAT (repo scope) that can read the certs repo |

After these exist, the workflow runs fully headless.

## Running locally (optional)

The same lane works from a Mac if you export the env vars above:

```bash
bundle install
ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_KEY_P8=$(base64 -i AuthKey_XXXX.p8) \
MATCH_GIT_URL=… MATCH_PASSWORD=… \
bundle exec fastlane beta
```

## Build numbering notes

- `CFBundleVersion` comes from the `CURRENT_PROJECT_VERSION` build setting
  (the Info.plist uses `$(CURRENT_PROJECT_VERSION)`); CI overrides it per
  build, so the project file never needs a version-bump commit.
- The old "Bump Build Number on Archive" run-script phase was removed — it
  edited Info.plist on every archive and would have fought the CI-injected
  build number.
- Historical TestFlight builds used fractional build numbers (`1.1`, `1.2`);
  CI continues from the next integer (`2`, `3`, …), which App Store Connect
  orders correctly.
