# Two Do

Two Do is a focused iOS time-blocking to-do list for turning a busy day into a clear plan. It keeps overdue work visible, places tasks on a daily timeline, and brings scheduled Google Calendar events into the same view.

![Two Do Today view](example1.jpeg)

## What it does

- Organizes work into overdue, today, upcoming, and undated task sections.
- Supports due dates, scheduled time blocks, notes, projects, tags, flags, locations, phone details, and subtasks.
- Provides an hourly Schedule view that combines Two Do tasks with read-only Google Calendar events.
- Searches tasks by title, project, and notes.
- Sends local notifications for due dates and scheduled blocks.
- Syncs task data across devices with SwiftData and the private CloudKit database when iCloud is available, with a local fallback for unsigned or simulator environments.
- Includes configurable home-screen widgets for focus, today, and upcoming tasks.

![Two Do Schedule view](example2.jpeg)

## Built with

- SwiftUI
- SwiftData
- CloudKit private database sync
- WidgetKit and App Intents
- Google Calendar OAuth 2.0 with PKCE
- XCUITest smoke tests

## Requirements

- macOS with Xcode and the iOS 18 SDK
- An iOS 18 or later device or simulator
- An Apple Developer account for CloudKit, notifications, widgets, and device signing

## Getting started

1. Clone the repository:

   ```bash
   git clone https://github.com/kadeemj/two-do.git
   cd two-do
   ```

2. Open `TwoDo.xcodeproj` in Xcode.
3. Select the `TwoDo` scheme and an iOS 18 or later destination.
4. Set your development team and run the app.

Two Do can run locally without an available CloudKit container; it falls back to a local SwiftData store. To use cross-device sync, configure the `iCloud.com.kadeem.twodo` container and the matching signing capabilities in your Apple Developer account.

Google Calendar integration is optional. Connect an account from the app's Settings tab after the Google OAuth configuration is available for the app's bundle identifier.

## Testing

The project includes unit tests for widget task data and XCUITest smoke tests for calendar events, date-only tasks, and notifications. Run the `TwoDo` test scheme from Xcode on an iOS 18 or later simulator.

## Releases

TestFlight releases are configured through GitHub Actions and fastlane. See [`docs/testflight.md`](docs/testflight.md) for signing setup and release instructions.

## License

No license has been published yet.
