# T2Do — App Review readiness

Updated September 18, 2026 for the approved replacement of direct Google OAuth with EventKit device calendars. A NEW TestFlight build and physical-device recording are required. Build 13's recorded walkthrough is retained in `app-review-recordings/T2Do-1.0-13-review-walkthrough.mov` as historical footage, not evidence of the new implementation. Apple's message requests additional information under Guideline 2.1; it does not identify a particular crash or require a redesign.

## Findings before replying

| Item | Evidence | Required next step |
| --- | --- | --- |
| Replacement binary uploaded | Rejected build: 1.0 (12). Build 1.0 (14) was uploaded from `c427360` with EventKit, flat Settings, the privacy link, and manifests. Apple processing and physical installation have not been verified. | Confirm processing and install the replacement; use the same build for physical QA, the recording, and App Store review. |
| Physical-device evidence missing | Device discovery timed out while initializing CoreDeviceService. No physical-device tests or recording were completed in this review. | Run the selected build on physical iPhone and iPad, since both families are enabled. Record on a device running the latest public OS required by Apple's message. |
| Privacy policy publication pending | `website/index.html` links to `privacy/`, `website/privacy/index.html` contains the policy, and Settings → About links directly to `https://t2do.app/privacy/`. | Publish and verify the public policy URL, then set it in App Store Connect. Apple guideline 5.1.1(i) requires both metadata and in-app access. |
| Calendar permission changed | EventKit requires Full Access to read events; the app contains no event-writing operations. Calendar selection starts empty. | Demonstrate permission, explicit selection, event display, denial recovery, and disconnect on a physical device. |
| No provider login required | Calendars must already be configured in Apple Calendar. Google OAuth source and callback scheme have been removed. | Provide sample events on the review device; no T2Do or Google demo credentials are needed. |
| Legacy Google credential cleanup | The next app launch removes the five app-owned Google Keychain entries. It does not revoke the old grant on Google's servers. | Existing users may remove T2Do from their Google Account's third-party connections separately. Do not claim server-side revocation. |
| Marketing privacy claim corrected | The unsupported end-to-end encryption claim has been removed; the website now describes private CloudKit sync. | Verify the corrected copy on the deployed website. |

App Store screenshots, age rating, privacy disclosures, support URL, availability, and the current App Review Notes have not been inspected in App Store Connect. Confirm them against the actual release before resubmission. A replacement binary is needed if fixes change the app; the information request alone does not establish that a new binary is necessary.

## Physical-device recording script

Use the exact TestFlight build intended for review. Use synthetic tasks and calendar entries, with no personal appointments or private task notes. Keep the recording a straightforward demonstration of the real app; a Simulator recording does not satisfy this request.

Before recording, confirm Software Update reports the latest public OS, and record the device model, OS version, TestFlight version/build, and date in your QA notes. Start screen recording while on the Home Screen; the first app action must be launching T2Do.

1. Launch T2Do. Show the initial screen and respond to notification permission if prompted. Show that a T2Do login is not required.
2. Create “Prepare weekly plan” with a note, today's due date, and a 30-minute time block. Save and show it in Today.
3. Open Schedule and show the saved time block. Open the task, choose Edit, change the start time, save, and show the result.
4. Create a project called “Personal” and a tag called “Planning” in Settings. Assign them to the task. Add one subtask and a flag if present in the selected build.
5. Create “Review yesterday's notes” with yesterday's due date. Show that it appears in Overdue, then complete it.
6. Search for “weekly,” open the matching task, and show the saved details.
7. If present in the release, demonstrate one recurring task and the next occurrence created after completion.
8. Show a local reminder using a disposable task scheduled a few minutes ahead. Leave the app to show the alert; return through the alert if supported.
9. Prepare a synthetic timed event and all-day event in Apple Calendar. In T2Do Settings, tap Connect Calendars, show the Full Access prompt, then open Choose Calendars and enable the demo calendar. Open the Calendar tab and show both events. Turn off the calendar selection and show events disappear; enable it again, then Disconnect Calendars and verify they disappear again. Do not record account passwords or unrelated private calendar content.
10. Add a T2Do widget from the Home Screen widget gallery, show task content, and tap it to open the app.
11. Delete a disposable task and show the result. Do not delete real user data for the demonstration.

Keep the video accessible to the reviewer without a request-access flow. Use the same working video link in both the reply and Notes. Confirm playback from a signed-out browser. This is review evidence, not necessarily the public App Store preview video.

There is no app-owned account creation, so do not invent a registration or deletion flow. Explain optional device-calendar permission separately. Personal tasks are user-entered content, but the app has no public publishing or social exchange. No in-app paid access was found.

## QA record

### Local automated validation (not physical-device QA)

On the iPhone Air Simulator running iOS 26.5:

- Debug and Release builds succeeded. Release launched on the Simulator. Existing `DayTimelineStrip.swift` Combine-import warnings remain.
- 29 unit tests passed initially; the final calendar suite passed all 9 tests, including the added overnight-event case.
- The calendar UI test passed selection/deselection, event display, disconnect/reconnect, and absence of the iCloud container row and Google login.
- A separate UI test passed the REAL iOS calendar-permission flow: deny access, keep task UI usable, reset permission for the test, grant Full Access, open calendar selection, and disconnect.
- Calendar event display in the smoke test uses DEBUG-only fixtures. Real provider synchronization and event retrieval still need physical-device validation.
- Screenshot: `app-review-recordings/device-calendar-settings-simulator.png`. This is Simulator verification, not Apple's required physical-device recording.
- Initial unsigned test execution failed because CloudKit entitlements were absent; normal Simulator signing resolved startup. No persistence code was changed for this.

Fill in actual results. A code inspection or successful Simulator test is not a physical-device pass.

Rejected version/build: 1.0 (12), confirmed by the developer
Candidate version/build for new QA and recording: 1.0 (14), uploaded; processing and installation verification pending
TestFlight install confirmed: Developer reports 1.0 (13) running on the physical iPhone
iPhone model / OS: Developer reports “iPhone 17 air” / iOS 27; confirm exact Model Name and OS version in Settings → General → About before sending
iPhone QA date and results: PENDING
iPad model / OS / date: PENDING
Recording URL: PENDING new physical-device recording (build 13 recording saved locally, 101 seconds)

| Check on each supported device family | Expected result | Actual result |
| --- | --- | --- |
| Launch, force-quit, relaunch | No crash; saved tasks persist | NOT RUN |
| Calendar permission denied; notifications denied | Core task flows remain usable | NOT RUN |
| Create, edit, complete, delete | Correct task and list update; persistence after relaunch | NOT RUN |
| Due yesterday, today, future, and undated | Correct sections and day boundaries | NOT RUN |
| Schedule and overlapping time blocks | Correct placement and usable layout | NOT RUN |
| Projects, tags, subtasks, search | Saved changes and correct results | NOT RUN |
| Recurrence, if in selected build | Exactly one appropriate successor | NOT RUN |
| Local notifications | Correct time; editing/deletion does not leave obsolete alerts | NOT RUN |
| Calendar permission, selection, events, revocation, disconnect | Correct selected events; no stale events after disconnect or revocation | NOT RUN |
| Offline use and reconnect | Local task edits persist; failures recover | NOT RUN |
| iCloud sync between physical devices | Create/edit/complete/delete reaches the other device | NOT RUN |
| Widgets and task opening | Current data; correct destination | NOT RUN |
| iPad layout, rotation, larger text, light/dark | Main controls readable and reachable | NOT RUN |
| Privacy and support links | Open valid, accessible destinations | NOT RUN |

## Sending the response

1. Finish QA and resolve release blockers. If the binary changes, upload and test the replacement build and record that build.
2. Complete all bracketed fields in `app-review-response.md`; verify each statement against the selected build. Keep private credentials out of repository files.
3. Add the completed six-part information and recording link to App Review Information → Notes. Add any necessary review credentials in the review account fields.
4. Reply in the App Review conversation with the same information and recording. This step sends an external message; this preparation has not sent it.
5. Follow the submission controls available for the actual App Store Connect status. Verify the correct build and updated metadata before submitting again, if required.

## References

- Apple review guidelines, including 2.1 and 5.1.1: https://developer.apple.com/app-store/review/guidelines/
- Apple review preparation: https://developer.apple.com/app-store/review/
- Apple EventKit access: https://developer.apple.com/documentation/eventkit/accessing-the-event-store
- Apple's request provided in this conversation is the authority for the physical-device recording and six numbered answers.
