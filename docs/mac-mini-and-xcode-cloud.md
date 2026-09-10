# Mac Mini + Xcode Cloud (Linux-first workflow)

T2Do’s primary checkout lives on a **Linux box**, which cannot run Xcode.
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

## Xcode Cloud

Workflow **creation is automated** via the App Store Connect API once two
Apple-only prerequisites exist. TestFlight stays on GitHub Actions.

### Automated path

| Piece | Path |
| --- | --- |
| Script | [`scripts/create_xcode_cloud_workflow.py`](../scripts/create_xcode_cloud_workflow.py) |
| Dispatch workflow | [`.github/workflows/ios-xcode-cloud-setup.yml`](../.github/workflows/ios-xcode-cloud-setup.yml) |
| Hooks | [`ci_scripts/`](../ci_scripts/) |

Creates (or reuses) **PR Build & Test**: Build + Test on PRs targeting
`main`, scheme `TwoDo`, container `TwoDo.xcodeproj` — **no** TestFlight
post-action.

```bash
# Locally (Mac Mini has the .p8; issuer is the ASC API Issuer UUID)
export ASC_KEY_ID=…
export ASC_ISSUER_ID=…
export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_….p8
python3 scripts/create_xcode_cloud_workflow.py

# Or: Actions → Xcode Cloud Workflow Setup → Run workflow
# (uses ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_P8 repo secrets)
```

### One-time ASC steps (API cannot do these)

Script exits `2` until both are done:

1. **Get Started** for T2Do:  
   https://appstoreconnect.apple.com/apps/6791229236/ci
2. **Grant GitHub** access so Xcode Cloud can clone `kadeemj/two-do`  
   (same ASC Xcode Cloud UI → repository picker / Manage Repositories).

Today ASC already has Xcode Cloud products for other apps, and GitHub repos
`kadeemj/corecredit` + `hiddenkah/jefferyhome` — **not** T2Do yet.

After those clicks, re-run the script / dispatch workflow; it should print
the new workflow URL.

## What stays on GitHub Actions (hosted macOS)

- [`.github/workflows/ios-testflight.yml`](../.github/workflows/ios-testflight.yml) — TestFlight
- [`.github/workflows/ios-signing.yml`](../.github/workflows/ios-signing.yml) — match profile sync

Do not move those lanes to the Mac Mini unless you intentionally want
local signing/uploads.
