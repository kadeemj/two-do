import SwiftUI
import SwiftData

enum TaskEditorMode {
    case create
    case edit(TodoTask)
}

struct AddEditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.sortIndex) private var projects: [Project]

    let mode: TaskEditorMode

    // Existing tasks open read-only; Edit switches to the form and Save returns here.
    @State private var isViewing: Bool

    @State private var title = ""
    @State private var notes = ""
    @State private var dueAt: Date = .now
    @State private var hasDue = true
    @State private var scheduledStart: Date = .now
    @State private var hasSchedule = false
    @State private var durationMinutes: Int = 30
    @State private var hasLocation = false
    @State private var hasPhone = false
    @State private var isFlagged = false
    @State private var locationName = ""
    @State private var selectedProjectID: UUID?
    @State private var subtaskTitle = ""
    @State private var pendingSubtasks: [String] = []

    init(mode: TaskEditorMode) {
        self.mode = mode
        if case .edit = mode {
            _isViewing = State(initialValue: true)
        } else {
            _isViewing = State(initialValue: false)
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var navigationTitle: String {
        if isViewing { return "Task" }
        return isEditing ? "Edit Task" : "New Task"
    }

    private var selectedProject: Project? {
        projects.first { $0.id == selectedProjectID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isViewing, case .edit(let task) = mode {
                    TaskDetailContent(task: task)
                } else {
                    editorForm
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isViewing {
                        Button("Done") { dismiss() }
                    } else if isEditing {
                        Button("Cancel") {
                            load()
                            withAnimation(.snappy) { isViewing = true }
                        }
                    } else {
                        Button("Cancel") { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isViewing {
                        Button("Edit") {
                            load()
                            withAnimation(.snappy) { isViewing = false }
                        }
                        .fontWeight(.semibold)
                    } else {
                        Button("Save") { save() }
                            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    private var editorForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                flatSection("Details") {
                    FlatTextField(placeholder: "Title", text: $title)
                    FlatDivider()
                    FlatTextField(placeholder: "Notes", text: $notes, axis: .vertical)
                }

                flatSection("When") {
                    FlatToggle(title: "Due date", isOn: $hasDue)
                    if hasDue {
                        FlatDivider()
                        DatePicker("Due", selection: $dueAt, displayedComponents: .date)
                            .padding(.vertical, 10)
                    }
                    FlatDivider()
                    FlatToggle(title: "Time block", isOn: $hasSchedule)
                    if hasSchedule {
                        FlatDivider()
                        DatePicker("Starts", selection: $scheduledStart)
                            .padding(.vertical, 10)
                        FlatDivider()
                        Stepper(
                            "Duration: \(DateFormatting.durationLabel(durationMinutes))",
                            value: $durationMinutes,
                            in: 5...480,
                            step: 5
                        )
                        .padding(.vertical, 10)
                    }
                }

                flatSection("Project") {
                    Picker("Project", selection: $selectedProjectID) {
                        Text("None").tag(Optional<UUID>.none)
                        ForEach(projects, id: \.id) { project in
                            Text(project.name).tag(Optional(project.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 10)
                }

                flatSection("Subtasks") {
                    ForEach(Array(pendingSubtasks.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                        if index < pendingSubtasks.count - 1 {
                            FlatDivider()
                        }
                    }
                    if !pendingSubtasks.isEmpty {
                        FlatDivider()
                    }
                    HStack(spacing: 12) {
                        FlatTextField(placeholder: "Add subtask", text: $subtaskTitle)
                        Button("Add") {
                            let trimmed = subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }
                            pendingSubtasks.append(trimmed)
                            subtaskTitle = ""
                        }
                        .disabled(subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func flatSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.top, 24)
                .padding(.bottom, 8)

            content()

            FlatDivider()
                .padding(.top, 4)
        }
    }

    private func load() {
        guard case .edit(let task) = mode else {
            selectedProjectID = projects.first?.id
            return
        }
        title = task.title
        notes = task.notes
        hasDue = task.dueAt != nil
        dueAt = task.dueAt ?? .now
        hasSchedule = task.scheduledStart != nil
        scheduledStart = task.scheduledStart ?? .now
        durationMinutes = task.durationMinutes ?? 30
        hasLocation = task.hasLocation
        hasPhone = task.hasPhone
        isFlagged = task.isFlagged
        locationName = task.locationName ?? ""
        selectedProjectID = task.project?.id
        pendingSubtasks = (task.subtasks ?? []).map(\.title)
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let task: TodoTask
        switch mode {
        case .create:
            task = TodoTask(title: trimmed, sortIndex: Date().timeIntervalSince1970)
            modelContext.insert(task)
        case .edit(let existing):
            task = existing
            task.title = trimmed
        }

        task.notes = notes
        // Due dates are date-only, stored at start of day.
        task.dueAt = hasDue ? Calendar.current.startOfDay(for: dueAt) : nil
        task.dueHasTime = false
        task.scheduledStart = hasSchedule ? scheduledStart : nil
        task.durationMinutes = (hasSchedule || durationMinutes > 0) ? durationMinutes : nil
        task.hasLocation = hasLocation
        task.hasPhone = hasPhone
        task.isFlagged = isFlagged
        task.locationName = hasLocation ? locationName : nil
        task.project = selectedProject
        task.updatedAt = .now

        if case .edit = mode {
            for old in task.subtasks ?? [] {
                modelContext.delete(old)
            }
        }
        for (index, name) in pendingSubtasks.enumerated() {
            let sub = TodoTask(title: name, sortIndex: Double(index), project: selectedProject, parent: task)
            modelContext.insert(sub)
        }

        try? modelContext.save()
        if case .edit = mode {
            withAnimation(.snappy) { isViewing = true }
        } else {
            dismiss()
        }
    }
}

// MARK: - Read-only detail

private struct TaskDetailContent: View {
    let task: TodoTask

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                detailSection("Details") {
                    Text(task.title)
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                    if !task.notes.isEmpty {
                        FlatDivider()
                        Text(NotesFormatting.attributedNotes(task.notes))
                            .tint(TwoDoColor.accentBlue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                }

                if task.dueAt != nil || task.scheduledStart != nil {
                    detailSection("When") {
                        if let due = task.dueAt {
                            detailRow("Due", DateFormatting.relativeDue(due))
                        }
                        if let start = task.scheduledStart {
                            if task.dueAt != nil {
                                FlatDivider()
                            }
                            detailRow(
                                "Starts",
                                "\(DateFormatting.shortDay.string(from: start)), \(DateFormatting.time.string(from: start))"
                            )
                            if let minutes = task.durationMinutes {
                                FlatDivider()
                                detailRow("Duration", DateFormatting.durationLabel(minutes))
                            }
                        }
                    }
                }

                if let project = task.project {
                    detailSection("Project") {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(TwoDoColor.project(from: project.colorHex))
                                .frame(width: 10, height: 10)
                            Text(project.name)
                        }
                        .padding(.vertical, 12)
                    }
                }

                if let subtasks = task.subtasks, !subtasks.isEmpty {
                    detailSection("Subtasks") {
                        let sorted = subtasks.sorted { $0.sortIndex < $1.sortIndex }
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, subtask in
                            Text(subtask.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                            if index < sorted.count - 1 {
                                FlatDivider()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func detailSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.6)
                .padding(.top, 24)
                .padding(.bottom, 8)

            content()

            FlatDivider()
                .padding(.top, 4)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Flat field helpers

private struct FlatTextField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        Group {
            if axis == .vertical {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(3...6)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .textFieldStyle(.plain)
        .padding(.vertical, 12)
    }
}

private struct FlatToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .padding(.vertical, 10)
            .tint(TwoDoColor.accentBlue)
    }
}

private struct FlatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.1))
            .frame(height: 0.5)
    }
}
