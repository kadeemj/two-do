import SwiftUI
import SwiftData

struct ProjectManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortIndex) private var projects: [Project]
    @State private var editor: ProjectEditorDestination?

    var body: some View {
        List {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No Projects",
                    systemImage: "folder",
                    description: Text("Create a project to group related tasks.")
                )
            } else {
                ForEach(projects, id: \.id) { project in
                    Button {
                        editor = .edit(project)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(TwoDoColor.project(from: project.colorHex))
                                .frame(width: 12, height: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.name)
                                    .foregroundStyle(.primary)
                                Text("\(project.tasks?.filter { $0.parent == nil }.count ?? 0) tasks")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            delete(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: move)
            }
        }
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
                    .disabled(projects.count < 2)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = .create
                } label: {
                    Label("Add Project", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editor) { destination in
            ProjectEditorView(destination: destination)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var reordered = projects
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, project) in reordered.enumerated() {
            project.sortIndex = index
        }
        try? modelContext.save()
    }

    private func delete(_ project: Project) {
        modelContext.delete(project)
        try? modelContext.save()
    }
}

private enum ProjectEditorDestination: Identifiable {
    case create
    case edit(Project)

    var id: String {
        switch self {
        case .create:
            return "create-project"
        case .edit(let project):
            return project.id.uuidString
        }
    }
}

private struct ProjectEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortIndex) private var projects: [Project]

    let destination: ProjectEditorDestination
    @State private var name: String
    @State private var selectedColorHex: String

    private let colors = [
        "3380F5", "F58C38", "F2C73F", "8BC85A",
        "3BB6A5", "9E7AE6", "F26B6B", "8A8F98"
    ]

    init(destination: ProjectEditorDestination) {
        self.destination = destination
        switch destination {
        case .create:
            _name = State(initialValue: "")
            _selectedColorHex = State(initialValue: "3380F5")
        case .edit(let project):
            _name = State(initialValue: project.name)
            _selectedColorHex = State(initialValue: project.colorHex)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 16) {
                        ForEach(colors, id: \.self) { hex in
                            Button {
                                selectedColorHex = hex
                            } label: {
                                Circle()
                                    .fill(TwoDoColor.project(from: hex))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if selectedColorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Project color")
                            .accessibilityValue(selectedColorHex == hex ? "Selected" : "")
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isCreating ? "New Project" : "Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var isCreating: Bool {
        if case .create = destination { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }

        switch destination {
        case .create:
            let nextIndex = (projects.map(\.sortIndex).max() ?? -1) + 1
            modelContext.insert(
                Project(name: trimmedName, colorHex: selectedColorHex, sortIndex: nextIndex)
            )
        case .edit(let project):
            project.name = trimmedName
            project.colorHex = selectedColorHex
        }

        try? modelContext.save()
        dismiss()
    }
}

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var editor: TagEditorDestination?

    var body: some View {
        List {
            if tags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag",
                    description: Text("Create tags for flexible task grouping.")
                )
            } else {
                ForEach(tags, id: \.id) { tag in
                    Button {
                        editor = .edit(tag)
                    } label: {
                        HStack {
                            Label(tag.name, systemImage: "tag")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(tag.tasks?.filter { $0.parent == nil }.count ?? 0)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            delete(tag)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = .create
                } label: {
                    Label("Add Tag", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editor) { destination in
            TagEditorView(destination: destination)
        }
    }

    private func delete(_ tag: Tag) {
        modelContext.delete(tag)
        try? modelContext.save()
    }
}

private enum TagEditorDestination: Identifiable {
    case create
    case edit(Tag)

    var id: String {
        switch self {
        case .create:
            return "create-tag"
        case .edit(let tag):
            return tag.id.uuidString
        }
    }
}

private struct TagEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var tags: [Tag]

    let destination: TagEditorDestination
    @State private var name: String

    init(destination: TagEditorDestination) {
        self.destination = destination
        switch destination {
        case .create:
            _name = State(initialValue: "")
        case .edit(let tag):
            _name = State(initialValue: tag.name)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tag name", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle(isCreating ? "New Tag" : "Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(trimmedName.isEmpty || hasDuplicateName)
                }
            }
        }
    }

    private var isCreating: Bool {
        if case .create = destination { return true }
        return false
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editingTagID: UUID? {
        if case .edit(let tag) = destination { return tag.id }
        return nil
    }

    private var hasDuplicateName: Bool {
        tags.contains {
            $0.id != editingTagID
                && $0.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private func save() {
        guard !trimmedName.isEmpty, !hasDuplicateName else { return }

        switch destination {
        case .create:
            modelContext.insert(Tag(name: trimmedName))
        case .edit(let tag):
            tag.name = trimmedName
        }

        try? modelContext.save()
        dismiss()
    }
}
