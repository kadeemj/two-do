import SwiftUI
import EventKit

struct CalendarSettingsSection: View {
    @Environment(DeviceCalendarService.self) private var calendars
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            if calendars.isConnected {
                NavigationLink {
                    CalendarSelectionView()
                } label: {
                    Label("Choose Calendars", systemImage: "calendar")
                }
                LabeledContent("Selected calendars", value: "\(calendars.calendars.filter { calendars.selectedCalendarIDs.contains($0.id) }.count)")
                Button("Disconnect Calendars", role: .destructive) {
                    calendars.disconnect()
                }
            } else if calendars.authorizationStatus == .denied || calendars.authorizationStatus == .writeOnly {
                Text("Allow Full Access in Settings to display your calendar events. You can still use all task features without it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Calendar Permissions") { openSettings() }
            } else if calendars.authorizationStatus == .restricted {
                Text("Calendar access is restricted on this device. Task features are still available.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    Task { await calendars.connect() }
                } label: {
                    HStack {
                        Label("Connect Calendars", systemImage: "calendar.badge.plus")
                        Spacer()
                        if calendars.isRequestingAccess { ProgressView() }
                    }
                }
                .disabled(calendars.isRequestingAccess)
            }
            if let error = calendars.lastError {
                Text(error).font(.footnote).foregroundStyle(TwoDoColor.overdue)
            }
        } header: {
            Text("Device Calendars")
        } footer: {
            Text("Show calendars already synced with Apple Calendar, including iCloud, Google, and Outlook. iOS requires Full Access to read events; T2Do never changes them. Disconnecting hides events in T2Do. You can revoke permission in iOS Settings.")
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

private struct CalendarSelectionView: View {
    @Environment(DeviceCalendarService.self) private var calendars

    var body: some View {
        List {
            if !calendars.isConnected {
                Text("Connect calendars in Settings to choose which events appear.")
            } else if calendars.calendars.isEmpty {
                ContentUnavailableView("No Calendars", systemImage: "calendar",
                    description: Text("Add or enable a calendar account in iOS Settings, then return here."))
            } else {
                Section {
                    ForEach(calendars.calendars) { calendar in
                        Toggle(isOn: Binding(
                            get: { calendars.selectedCalendarIDs.contains(calendar.id) },
                            set: { calendars.setSelected($0, calendarID: calendar.id) }
                        )) {
                            HStack {
                                Circle()
                                    .fill(TwoDoColor.project(from: calendar.colorHex))
                                    .frame(width: 10, height: 10)
                                VStack(alignment: .leading) {
                                    Text(calendar.title)
                                    Text(calendar.source).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityIdentifier("calendar-selection-\(calendar.id)")
                    }
                } footer: {
                    Text("Choose the calendars to show alongside your tasks. With none selected, only T2Do tasks appear. Calendar choices apply to this device.")
                }
            }
        }
        .navigationTitle("Choose Calendars")
        .task { calendars.refresh() }
    }
}
