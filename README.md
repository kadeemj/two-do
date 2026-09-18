# T2Do

T2Do is a focused iOS time-blocking to-do list for turning a busy day into a clear plan. It keeps overdue work visible, places tasks on a daily timeline, and displays events from selected device calendars in the same view.

Website: [t2do.app](https://t2do.app)

![T2Do Today view](example1.jpeg)

## What it does

- Organizes work into overdue, today, upcoming, and undated task sections.
- Supports due dates, scheduled time blocks, notes, projects, tags, flags, locations, phone details, and subtasks.
- Provides an hourly Calendar view combining tasks with events from calendars synced to Apple Calendar, including iCloud, Google, and Outlook. Connect in Settings, grant calendar access, and choose calendars to display. No separate app login is required, and T2Do never edits calendar events.
- Searches tasks by title, project, and notes.
- Sends local notifications for due dates and scheduled blocks.
- Syncs task data across devices with SwiftData and the private CloudKit database when iCloud is available, with a local fallback for unsigned or simulator environments.
- Includes configurable home-screen widgets for focus, today, and upcoming tasks.

![T2Do Schedule view](example2.jpeg)

## Built with

- SwiftUI
- SwiftData
- CloudKit private database sync
- WidgetKit and App Intents
- EventKit for optional device-calendar access (iOS Full Access permission is required to read events)
- XCUITest smoke tests

## Build & CI

- **TestFlight:** GitHub Actions + fastlane — see [`docs/testflight.md`](docs/testflight.md).
- **Tests / Mac Mini / Xcode Cloud:** Linux cannot run Xcode. Use the Mac Mini over SSH and the self-hosted test workflow; connect Xcode Cloud from the Mini — see [`docs/mac-mini-and-xcode-cloud.md`](docs/mac-mini-and-xcode-cloud.md).
