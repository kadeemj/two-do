# Headless TestFlight releases

Two Do ships to TestFlight from GitHub Actions — no Xcode Organizer, no manual
signing, no 2FA. This doc covers the **one-time setup** and the
**per-release** flow.

- Workflow: [`.github/workflows/ios-testflight.yml`](../.github/workflows/ios-testflight.yml)
- fastlane lane: [`fastlane/Fastfile`](../fastlane/Fastfile) → `beta`

## How a release works

`fastlane beta` (run by the workflow) does:

1. `setup_ci` — creates a throwaway keychain on the runner.
2. Authenticates to App Store Connect with the **API key** (no Apple ID / 2FA).
3. `match (readonly)` — installs the distribution cert + App Store profile from
   the private certs repo.
4. Computes the next build number = highest on TestFlight + 1.
5. `build_app` — archives the **Release** config, injecting the build number
   via `CURRENT_PROJECT_VERSION` at build time (no project edit, no
   commit-back).
6. `upload_to_testflight` — uploads the build.

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
profile** for `com.kadeem.twodo`, encrypts them with `MATCH_PASSWORD`, and
pushes them to the certs repo. CI only ever reads them (the Matchfile pins
`readonly: true`).

> The App ID needs its capabilities (iCloud/CloudKit, Push Notifications)
> enabled in the developer portal so the profile match generates includes
> them — they should already be on from previous manual releases.

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
