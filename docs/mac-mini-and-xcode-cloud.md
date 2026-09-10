# Mac Mini + Xcode Cloud (Linux-first workflow)

Two Do’s primary checkout lives on a **Linux box**, which cannot run Xcode.
Day-to-day builds/tests use the **Mac Mini**; cloud CI for Apple-hosted
builds uses **Xcode Cloud**. TestFlight uploads stay on GitHub Actions
([`docs/testflight.md`](testflight.md)) — unchanged.

```text
Linux box  --SSH-->  Mac Mini (Xcode, Simulator, self-hosted runner)
                          |
                     GitHub Actions: iOS Tests (self-hosted)
                          |
GitHub (kadeemj/two-do) --clone--> Xcode Cloud (Apple-hosted build/test)
GitHub Actions macos-15 ----------> TestFlight (fastlane beta)
```

## Mac Mini access from Linux

Hostname/IP: `192.168.10.163` (`Kadeems-Mini.localdomain`)  
SSH user: `kadeem`  
Alias (on the Linux box):

```bash
ssh mac-mini
```

Config lives in `~/.ssh/config` as `Host mac-mini` (key:
`~/.ssh/corecredit_macmini_test`). The older wrapper
`/DATA/AppData/.codex/machines/mac-mini/ssh` still works.

### Dev checkout on the Mini

```bash
ssh mac-mini
cd ~/Developer/two-do   # git@github.com:kadeemj/two-do.git
git pull
# open in Xcode when you need the GUI:
open TwoDo.xcodeproj
# or headless:
xcodebuild test -scheme TwoDo -destination 'platform=iOS Simulator,name=iPhone 17'
```

From Linux, one-shot remote commands:

```bash
ssh mac-mini 'cd ~/Developer/two-do && git pull && xcodebuild -scheme TwoDo -version'
```

## Self-hosted GitHub Actions runner

Installed at `~/actions-runner` on the Mac Mini as LaunchAgent
`actions.runner.kadeemj-two-do.kadeems-mac-mini`.

| Field | Value |
| --- | --- |
| Runner name | `kadeems-mac-mini` |
| Labels | `self-hosted`, `macOS`, `ARM64`, `two-do-mac-mini` |
| Workflow | [`.github/workflows/ios-tests.yml`](../.github/workflows/ios-tests.yml) |

Useful commands (on the Mini):

```bash
cd ~/actions-runner
./svc.sh status
./svc.sh stop
./svc.sh start
```

Keep the Mac Mini awake / logged in so the LaunchAgent stays alive. Screen
Sharing or a logged-in GUI session is required for Simulator UI tests.

## Xcode Cloud (one-time, must finish on the Mac Mini)

Xcode Cloud workflows are created in **Xcode** or **App Store Connect** —
they cannot be fully provisioned from Linux. Repo hooks for Cloud are
already in [`ci_scripts/`](../ci_scripts/).

### 1. Grant GitHub access

On the Mac Mini (GUI session):

1. Open **Xcode** → **Settings → Accounts** — sign in with the Apple ID that
   owns team `JUQMKZZ7TJ`.
2. Open `~/Developer/two-do/TwoDo.xcodeproj`.
3. **Product → Xcode Cloud → Create Workflow…** (or App Store Connect →
   your app → **Xcode Cloud** → **Get Started**).
4. When prompted, connect the **GitHub** repository `kadeemj/two-do` and
   grant Apple access to the repo (App Store Connect GitHub App).

### 2. Recommended first workflow

Keep this separate from TestFlight (GitHub Actions owns releases):

| Setting | Suggestion |
| --- | --- |
| Name | `PR Build & Test` |
| Start condition | Pull requests to `main` (and optionally pushes to `main`) |
| Actions | **Build** + **Test** the `TwoDo` scheme |
| Destination | Latest iOS Simulator / managed device |
| Post-actions | None (do **not** auto-deploy to TestFlight) |

Archive + TestFlight can stay exclusively on the existing
`ios-testflight.yml` / `fastlane beta` path.

### 3. Custom scripts already in-repo

| Script | Purpose |
| --- | --- |
| [`ci_scripts/ci_post_clone.sh`](../ci_scripts/ci_post_clone.sh) | Sanity-check clone after Xcode Cloud checks out the repo |
| [`ci_scripts/ci_pre_xcodebuild.sh`](../ci_scripts/ci_pre_xcodebuild.sh) | Sets `TWODO_SMOKE_TEST` / `TWODO_SMOKE_CAL` for UI smoke hooks |

Make them executable after pull (`chmod +x ci_scripts/*.sh`) — Git should
preserve the executable bit once committed.

### 4. Confirm in App Store Connect

App Store Connect → **Apps → Two Do → Xcode Cloud** should list the
workflow and recent builds after the first push/PR.

## What stays on GitHub Actions (hosted macOS)

- [`.github/workflows/ios-testflight.yml`](../.github/workflows/ios-testflight.yml) — TestFlight
- [`.github/workflows/ios-signing.yml`](../.github/workflows/ios-signing.yml) — match profile sync

Do not move those lanes to the Mac Mini unless you intentionally want
local signing/uploads.
