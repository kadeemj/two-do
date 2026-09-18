# T2Do — response to Guideline 2.1

Draft updated for the EventKit replacement on September 18, 2026. This describes the NEW implementation, not TestFlight build 13. Build, upload, and physically test a replacement before sending. Replace every bracketed field and complete `app-review-readiness.md`. Do not claim testing that has not happened. Paste the completed response into both the App Review conversation and App Review Information → Notes.

---

Hello App Review team,

Thank you for your message. Below is the requested information for T2Do.

1. Physical-device demonstration and testing

Recording: [LINK ACCESSIBLE WITHOUT REQUESTING PERMISSION]
App version and build: [NEW VERSION / BUILD WITH DEVICE CALENDARS — NOT BUILD 13]
Physical device and operating system: iPhone Air, iOS 27 (developer-reported; confirm exact Model Name and OS version in Settings → General → About).
Test date: [DATE]
Other supported physical devices tested: [MODELS, OS VERSIONS, RESULTS]

The recording begins by launching T2Do from the Home Screen and demonstrates creating, scheduling, organizing, finding, editing, completing, and deleting personal tasks. It also shows the optional device-calendar permission flow, choosing calendars, viewing events, and disconnecting calendars.

[ONLY AFTER TESTING: We tested this build on the physical devices listed above and confirmed the demonstrated flows work.]

2. Purpose and target audience

T2Do is a personal task planner for iPhone and iPad, intended for individuals such as students, professionals, and anyone organizing day-to-day responsibilities. It helps users turn a task list into a practical daily plan by keeping overdue tasks visible and placing scheduled tasks alongside their calendar events. Users can organize tasks with projects, tags, notes, flags, and subtasks, and receive local reminders.

The app is intended for general public distribution, not employees or members of a specific organization.

3. Setup and access to main features

No T2Do account, registration, invitation, activation code, or sample file is required. Launching the app opens the task interface. Notification permission is optional; declining it does not prevent task management.

Typical review flow:
- In Today, use the add-task control to create a task named “Plan tomorrow.” Set its due date to today, enable Time block, choose a start time and duration, and save.
- Open Schedule to see the task at its scheduled time.
- Open the task, choose Edit, change its notes or schedule, and save.
- In Settings → Organize, create a project or tag and assign it in the task editor.
- Open Search and search for “Plan tomorrow.”
- Complete a task using its completion control. Swipe a disposable task to delete it.
- Add a T2Do Home Screen widget using the system widget gallery to view tasks outside the app.

Task data is stored on the device. When iCloud is available, the app uses the user's private CloudKit database to sync across devices signed into the same Apple Account. There is no separate T2Do login for this feature.

Device-calendar access is optional. In Settings, select “Connect Calendars” and grant Full Access in the iOS permission prompt. iOS requires this permission to read existing events; T2Do does not add, edit, or delete calendar events. Select “Choose Calendars” and turn on the calendars you want displayed. The Calendar tab displays their events alongside tasks. Select “Disconnect Calendars” to hide those events and stop reading them in T2Do; system permission can also be revoked in iOS Settings.

No demo account credentials are required. To review calendar display, create a sample event in Apple Calendar on the review device, then enable that calendar in T2Do. Calendars from iCloud, Google, Outlook, or other providers must already be configured and synced with Apple Calendar. Signing into only a provider's separate app is insufficient.

T2Do does not create a user account, so there is no T2Do account registration or account-deletion flow. There is no Sign in with Apple or Google sign-in. Personal task content is not published to other app users, and there is no public feed, messaging, or social interaction requiring reporting or blocking controls.

There are no in-app purchases, subscriptions, paywalls, or paid feature unlocks in this build. [VERIFY AGAINST THE SUBMITTED BUILD.]

4. External services, tools, and platforms

- Apple SwiftData: on-device storage of tasks, projects, and tags.
- Apple iCloud / CloudKit: optional synchronization in the user's private database.
- Apple EventKit: optional access to selected calendars already on the device. Calendar-provider account authentication and synchronization are managed by iOS; T2Do does not directly authenticate with Google or call the Google Calendar API. Calendar events are displayed in memory, not copied into the T2Do task database.
- Apple UserNotifications: local task reminders.
- Apple WidgetKit and App Intents: Home Screen widgets and task-capture integration.

The inspected app contains no advertising SDK, payment processor, AI service, third-party analytics SDK, or developer-operated task backend. [CONFIRM THIS ALSO MATCHES THE DISTRIBUTED BUILD AND ACTUAL OPERATIONS.]

5. Regional availability and behavior

T2Do does not intentionally enable different task features or content by region. Dates and times use the device's calendar and time-zone settings. Optional iCloud synchronization and provider calendars depend on their availability and configuration on the device; core local task management works without calendar access.

[CONFIRM THE ABOVE AND THE SELECTED APP STORE TERRITORIES BEFORE SENDING.]

6. Regulated services and third-party material

T2Do is a general-purpose personal productivity app. It does not provide regulated financial, medical, gambling, or other regulated services. Calendar content is accessed with the user's iOS calendar permission and is displayed for that user; the app does not distribute a catalog of licensed third-party media.

[OWNER: CONFIRM RIGHTS TO THE APP'S ICON, IMAGES, AND OTHER INCLUDED MATERIAL. IF ANY MATERIAL REQUIRES A LICENSE, PROVIDE THE RELEVANT DOCUMENTATION HERE.]

Thank you for reviewing T2Do.
