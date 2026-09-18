import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TodoTask]
    @State private var iCloudStatusText = "Checking…"
    @State private var showingClearConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("iCloud Sync") {
                    LabeledContent("Status", value: iCloudStatusText)
                    Text("Tasks sync automatically via iCloud on all devices signed into the same Apple Account.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                CalendarSettingsSection()

                Section("Organize") {
                    NavigationLink {
                        ProjectManagementView()
                    } label: {
                        Label("Projects", systemImage: "folder")
                    }

                    NavigationLink {
                        TagManagementView()
                    } label: {
                        Label("Tags", systemImage: "tag")
                    }
                }

                Section("Data") {
                    LabeledContent("Open tasks", value: "\(tasks.filter { !$0.isCompleted && $0.parent == nil }.count)")
                    Button("Clear completed tasks", role: .destructive) {
                        showingClearConfirm = true
                    }
                }

                Section("About") {
                    LabeledContent("App", value: "T2Do")
                    Link(destination: URL(string: "https://t2do.app")!) {
                        LabeledContent("Website", value: "t2do.app")
                    }
                    Link(destination: URL(string: "https://t2do.app/privacy/")!) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    LabeledContent("Appearance", value: "System light / dark")
                    Text("A time-blocking todo list with overdue focus.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationTitle("Settings")
            .confirmationDialog("Clear all completed tasks?", isPresented: $showingClearConfirm, titleVisibility: .visible) {
                Button("Clear completed", role: .destructive) {
                    clearCompleted()
                }
            }
            .task {
                refreshICloudStatus()
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
