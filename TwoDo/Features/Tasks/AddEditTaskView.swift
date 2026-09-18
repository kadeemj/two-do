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
    @Query(sort: \Tag.name) private var tags: [Tag]

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
    @State private var phoneLabel = ""
    @State private var selectedProjectID: UUID?
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var recurrenceKind: RecurrenceKind?
    @State private var recurrenceInterval = 2
    @State private var recurrenceUnit: RecurrenceUnit = .day
    @State private var remindersEnabled = true
    @State private var selectedReminderOptions: Set<TaskReminderOption> = [.morningOf]
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

    private var selectedRecurrence: TaskRecurrence? {
        recurrenceKind.map {
            TaskRecurrence(kind: $0, interval: recurrenceInterval, unit: recurrenceUnit)
        }
    }

    private var availableReminderOptions: [TaskReminderOption] {
        TaskReminderPlan.availableOptions(hasDue: hasDue, hasSchedule: hasSchedule)
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

                flatSection("Repeat") {
                    Picker("Repeat", selection: $recurrenceKind) {
                        Text("Never").tag(Optional<RecurrenceKind>.none)
                        ForEach(RecurrenceKind.allCases) { kind in
                            Text(kind.title).tag(Optional(kind))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 10)

                    if recurrenceKind == .custom {
                        FlatDivider()
                        Stepper(
                            "Every \(recurrenceInterval) \(recurrenceUnit.label(for: recurrenceInterval))",
                            value: $recurrenceInterval,
                            in: 1...99
                        )
                        .padding(.vertical, 10)
                        FlatDivider()
                        Picker("Unit", selection: $recurrenceUnit) {
                            ForEach(RecurrenceUnit.allCases) { unit in
                                Text(unit.label(for: 2).capitalized).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.vertical, 10)
                    }

                    if recurrenceKind != nil && !hasDue && !hasSchedule {
                        FlatDivider()
                        Text("The next occurrence will use the completion day as its starting point.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    }
                }

                flatSection("Reminders") {
                    if !hasDue && !hasSchedule {
                        Text("Add a due date or time block to enable reminders.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        FlatToggle(title: "Remind me", isOn: $remindersEnabled)

                        if remindersEnabled {
                            ForEach(availableReminderOptions) { option in
                                FlatDivider()
                                Button {
                                    toggleReminder(option)
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.title)
                                                .foregroundStyle(.primary)
                                            Text(option.detail)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedReminderOptions.contains(option) {
                                            Image(systemName: "checkmark")
                                                .font(.body.weight(.semibold))
                                                .foregroundStyle(TwoDoColor.accentBlue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .accessibilityValue(
                                    selectedReminderOptions.contains(option) ? "Selected" : "Not selected"
                                )
                                .accessibilityHint("Double tap to toggle this reminder")
                            }
                        }
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

                flatSection("Tags") {
                    if tags.isEmpty {
                        Text("Create tags in Settings to assign them to tasks.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                            Button {
                                toggleTag(tag)
                            } label: {
                                HStack {
                                    Label(tag.name, systemImage: "tag")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if selectedTagIDs.contains(tag.id) {
                                        Image(systemName: "checkmark")
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(TwoDoColor.accentBlue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 11)
                            }
                            .buttonStyle(.plain)

                            if index < tags.count - 1 {
                                FlatDivider()
                            }
                        }
                    }
                }

                flatSection("Context") {
                    FlatToggle(title: "Flagged", isOn: $isFlagged)
                    FlatDivider()
                    FlatToggle(title: "Location", isOn: $hasLocation)
                    if hasLocation {
                        FlatDivider()
                        FlatTextField(placeholder: "Location name or address", text: $locationName)
                    }
                    FlatDivider()
                    FlatToggle(title: "Phone call", isOn: $hasPhone)
                    if hasPhone {
                        FlatDivider()
                        FlatTextField(placeholder: "Phone number or contact", text: $phoneLabel)
                            .keyboardType(.phonePad)
                    }
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
        phoneLabel = task.phoneLabel ?? ""
        selectedProjectID = task.project?.id
        selectedTagIDs = Set((task.tags ?? []).map(\.id))
        recurrenceKind = task.recurrence?.kind
        recurrenceInterval = task.recurrence?.interval ?? 2
        recurrenceUnit = task.recurrence?.unit ?? .day
        remindersEnabled = task.remindersEnabled
        selectedReminderOptions = task.reminderOptions
        pendingSubtasks = (task.subtasks ?? []).map(\.title)
    }

    private func toggleReminder(_ option: TaskReminderOption) {
        if selectedReminderOptions.contains(option) {
            let validSelection = selectedReminderOptions.intersection(Set(availableReminderOptions))
            guard validSelection.count > 1 else { return }
            selectedReminderOptions.remove(option)
        } else {
            selectedReminderOptions.insert(option)
        }
    }

    private func toggleTag(_ tag: Tag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
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
        task.locationName = hasLocation ? locationName.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        task.phoneLabel = hasPhone ? phoneLabel.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        task.project = selectedProject
        task.tags = tags.filter { selectedTagIDs.contains($0.id) }
        task.recurrence = selectedRecurrence
        let reminderAnchorExists = hasDue || hasSchedule
        task.remindersEnabled = remindersEnabled && reminderAnchorExists
        let availableReminders = Set(availableReminderOptions)
        let validReminders = selectedReminderOptions.intersection(availableReminders)
        task.reminderOptions = validReminders.isEmpty && task.remindersEnabled
            ? TaskReminderPlan.defaultOptions(hasDue: hasDue, hasSchedule: hasSchedule)
            : validReminders
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

                if task.dueAt != nil || task.scheduledStart != nil {
                    detailSection("Reminders") {
                        detailRow("Alerts", task.reminderSummary)
                    }
                }

                if let recurrence = task.recurrence {
                    detailSection("Repeat") {
                        detailRow("Repeats", recurrence.displayName)
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

                if let tags = task.tags?.sorted(by: {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }), !tags.isEmpty {
                    detailSection("Tags") {
                        ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                            Label(tag.name, systemImage: "tag")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                            if index < tags.count - 1 {
                                FlatDivider()
                            }
                        }
                    }
                }

                if task.isFlagged || task.hasLocation || task.hasPhone {
                    detailSection("Context") {
                        if task.isFlagged {
                            detailRow("Flagged", "Yes")
                        }
                        if task.hasLocation {
                            if task.isFlagged {
                                FlatDivider()
                            }
                            detailRow(
                                "Location",
                                task.locationName?.isEmpty == false ? (task.locationName ?? "Added") : "Added"
                            )
                        }
                        if task.hasPhone {
                            if task.isFlagged || task.hasLocation {
                                FlatDivider()
                            }
                            detailRow(
                                "Phone",
                                task.phoneLabel?.isEmpty == false ? (task.phoneLabel ?? "Added") : "Added"
                            )
                        }
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
