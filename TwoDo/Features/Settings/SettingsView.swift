import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TodoTask]
    @State private var iCloudStatusText = "Checking…"
    @State private var showingClearConfirm = false
    @State private var googleAuth = GoogleCalendarAuthService()

    var body: some View {
        NavigationStack {
            List {
                Section("iCloud Sync") {
                    LabeledContent("Status", value: iCloudStatusText)
                    LabeledContent("Container", value: ModelContainerFactory.cloudKitContainerID)
                    Text("Tasks sync automatically via iCloud on all devices signed into the same Apple Account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    if googleAuth.isSignedIn {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.checkmark")
                                .font(.system(size: 22))
                                .foregroundStyle(TwoDoColor.accentBlue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(googleAuth.displayName ?? "Google Calendar")
                                    .font(.body.weight(.medium))
                                Text(googleAuth.email ?? "Connected")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        Button("Sign Out of Google Calendar", role: .destructive) {
                            googleAuth.signOut()
                        }
                    } else {
                        Button {
                            Task { await googleAuth.signIn() }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 22))
                                    .foregroundStyle(TwoDoColor.accentBlue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Sign in with Google Calendar")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("Connect events to your schedule")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if googleAuth.isBusy {
                                    ProgressView()
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(googleAuth.isBusy)
                    }

                    if let error = googleAuth.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(TwoDoColor.overdue)
                    }

                    if !GoogleCalendarConfig.isConfigured {
                        Text("Create an iOS OAuth client (bundle ID com.kadeem.twodo), paste the Client ID into GoogleCalendarConfig.swift, and set the matching URL scheme in Info.plist.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Google Calendar")
                }

                Section("Data") {
                    LabeledContent("Open tasks", value: "\(tasks.filter { !$0.isCompleted && $0.parent == nil }.count)")
                    Button("Clear completed tasks", role: .destructive) {
                        showingClearConfirm = true
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "Two Do")
                    LabeledContent("Appearance", value: "System light / dark")
                    Text("A time-blocking todo list with overdue focus.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Clear all completed tasks?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("Clear completed", role: .destructive) {
                    clearCompleted()
                }
            }
            .task {
                refreshICloudStatus()
                googleAuth.reloadFromKeychain()
            }
        }
    }

    private func clearCompleted() {
        for task in tasks where task.isCompleted {
            modelContext.delete(task)
        }
        try? modelContext.save()
    }

    /// Do not call `CKContainer(identifier:)` here — CloudKit fatally traps when that
    /// container isn’t provisioned for the signed build (Simulator / no team).
    private func refreshICloudStatus() {
        if !ModelContainerFactory.isCloudBacked {
            iCloudStatusText = "Unavailable — local only"
        } else if FileManager.default.ubiquityIdentityToken == nil {
            iCloudStatusText = "Sign in to iCloud to sync"
        } else {
            iCloudStatusText = "Syncing via iCloud"
        }
    }
}
