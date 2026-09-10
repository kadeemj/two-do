# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project overview

T2Do is an iOS time-blocking to-do list app ("a time-blocking todo list with overdue focus"). Tasks have due dates (timed or date-only), scheduled time blocks, projects, tags, subtasks, and flags. Four tabs (`TwoDo/App/RootTabView.swift`): **Today** (overdue + today list with a day timeline strip), **Schedule** (hourly timeline merging tasks with Google Calendar events), **Search**, and **Settings**. Data syncs across devices via iCloud/CloudKit; due dates and time blocks fire local notifications; Google Calendar events are displayed read-only via OAuth.

## Structure

- `TwoDo/App/` — `TwoDoApp.swift` (`@main`; builds the ModelContainer, activates notifications, resyncs on save/scene changes), `RootTabView.swift`.
- `TwoDo/Models/` — SwiftData `@Model` classes: `TodoTask`, `Project`, `Tag`.
- `TwoDo/Persistence/` — `ModelContainer+CloudKit.swift` (`ModelContainerFactory`: CloudKit-backed container with local fallback), `TaskQueries.swift` (pure filtering/sorting plus `TimelineLayout`/`ScheduleLayout` shared by Today & Schedule).
- `TwoDo/Services/` — `NotificationScheduler.swift` (singleton; rebuilds all pending local notifications on every resync).
- `TwoDo/Features/` — SwiftUI views by feature: `Today/`, `Schedule/` (incl. `GoogleCalendarEventsService`), `Search/`, `Tasks/` (`AddEditTaskView`), `Settings/` (incl. `GoogleCalendarAuthService`, `KeychainStore`).
- `TwoDo/Design/` — design tokens: `TwoDoColor`, `TwoDoSpacing` (`ColorTokens.swift`), `TwoDoTypography`, `DateFormatting`.
- `TwoDo/Preview/` — `SampleData.swift` (demo seeding for previews/first run).
- `TwoDoUITests/` — XCUITest smoke tests driven by launch-environment hooks (see gotchas).
- `fastlane/`, `.github/workflows/`, `docs/testflight.md` — release tooling (see below).
- `ci_scripts/` — Xcode Cloud hooks; `docs/mac-mini-and-xcode-cloud.md` — Mac Mini SSH + self-hosted tests + Xcode Cloud setup.

## Architecture

- **UI:** SwiftUI only. Views read data reactively via `@Query` and own state with `@State`/`@Environment(\.modelContext)`.
- **Persistence:** SwiftData, single schema `[TodoTask, Project, Tag]`.
- **Sync:** CloudKit private database `iCloud.com.kadeem.twodo` via SwiftData. `ModelContainerFactory.make()` prefers CloudKit and falls back to a local-only store (same store file, so local data is promoted on first sync); `isCloudBacked` records which mode is active.
- **Business/layout logic** lives in pure enums/structs (`TaskQueries`, `TimelineLayout`, `ScheduleLayout`, `DateFormatting`) operating on in-memory arrays — keep new logic there, not in views.
- **Google Calendar:** OAuth 2.0 + PKCE via `ASWebAuthenticationSession` (`GoogleCalendarAuthService`), tokens in the Keychain (`KeychainStore`), events fetched with `URLSession` against the Calendar v3 REST API (`GoogleCalendarEventsService`, `@Observable`). Read-only.

## Critical conventions & gotchas

- **CloudKit-compatible models:** every `@Model` stored property must be optional or have an *inline* default value — initializer defaults do NOT satisfy CloudKit. Relationships must be optional (`[...]?`). Breaking this silently kills iCloud sync.
- **Never call `CKContainer(identifier:)`** for status checks — it traps fatally when the container isn't provisioned (Simulator, no signing team). Use `ModelContainerFactory.isCloudBacked` and `FileManager.default.ubiquityIdentityToken` instead (see `SettingsView.refreshICloudStatus()`).
- **Notifications are always fully rebuilt**, never incrementally edited: call `NotificationScheduler.shared.resync(...)` after data changes. Requests are namespaced with the `twodo-task-` prefix and capped at 60 pending (soonest first) to respect iOS's 64-request limit.
- The task model is named `TodoTask`, not `Task`, to avoid colliding with Swift concurrency's `Task`.
- **UI-test hooks** are `#if DEBUG`-gated environment flags: `TWODO_SMOKE_TEST` (seed a due-soon task), `TWODO_SMOKE_CAL` (fake Google events), `TWODO_SMOKE_TAB` (open a tab directly). They live in `TwoDoApp.swift`, `RootTabView.swift`, and `GoogleCalendarEventsService.swift` — preserve them when editing those files.
- Colors are stored as 6-character hex strings without `#`; the default project color is `3380F5`.

## Build, test, release

- Targets: `TwoDo` (bundle id `com.kadeem.twodo`, iOS 18.0+, iPhone & iPad) and `TwoDoUITests`; shared scheme `TwoDo`. Building requires Xcode on macOS — it cannot be built or tested in a Linux session.
- **Mac Mini:** Linux SSHs with `ssh mac-mini` (`192.168.10.163`). Dev checkout: `~/Developer/two-do`. Self-hosted runner `kadeems-mac-mini` runs `.github/workflows/ios-tests.yml`. See `docs/mac-mini-and-xcode-cloud.md`.
- **Xcode Cloud:** Apple-hosted build/test (not TestFlight). Create the workflow with `scripts/create_xcode_cloud_workflow.py` or the `ios-xcode-cloud-setup` Action after one-time ASC Get Started + GitHub grant; hooks live in `ci_scripts/`.
- **TestFlight release is fully headless:** push a tag matching `ios-v*` (e.g. `ios-v1.0.1`) or manually dispatch the "iOS TestFlight" workflow (`.github/workflows/ios-testflight.yml`), which runs `bundle exec fastlane beta` on hosted `macos-15` with App Store Connect API-key auth and `match` (readonly, certs in a separate private repo).
- Versioning: `MARKETING_VERSION` is bumped manually in Xcode; the build number (`CURRENT_PROJECT_VERSION`) is computed and injected by CI (latest TestFlight build + 1) — no version-bump commits. Full details in `docs/testflight.md`.
