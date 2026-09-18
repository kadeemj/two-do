import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.sortIndex) private var tasks: [TodoTask]
    @State private var query = ""
    @State private var editingTask: TodoTask?

    private var results: [TodoTask] {
        let roots = tasks.filter { !$0.isCompleted && $0.parent == nil }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return roots.sorted { $0.sortIndex < $1.sortIndex } }
        return roots.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || ($0.project?.name.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.tags?.contains { $0.name.localizedCaseInsensitiveContains(q) } ?? false)
                || ($0.locationName?.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.phoneLabel?.localizedCaseInsensitiveContains(q) ?? false)
                || $0.notes.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(results, id: \.id) { task in
                    Button {
                        editingTask = task
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(TwoDoTypography.taskTitle)
                                .foregroundStyle(task.isOverdue() ? TwoDoColor.overdue : Color.primary)
                            HStack(spacing: 8) {
                                if let project = task.project {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(TwoDoColor.project(from: project.colorHex))
                                            .frame(width: 6, height: 6)
                                        Text(project.name)
                                            .font(TwoDoTypography.metadata)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if let tag = task.tags?.sorted(by: {
                                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                                }).first {
                                    Label(tag.name, systemImage: "tag")
                                        .font(TwoDoTypography.metadata)
                                        .foregroundStyle(.secondary)
                                }
                                if let due = task.dueAt {
                                    Text(DateFormatting.relativeDue(due))
                                        .font(TwoDoTypography.metadata)
                                        .foregroundStyle(TwoDoColor.accentBlue)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            delete(task)
                        } label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search tasks")
            .navigationTitle("Search")
            .sheet(item: $editingTask) { task in
                AddEditTaskView(mode: .edit(task))
            }
        }
    }

    private func delete(_ task: TodoTask) {
        withAnimation(.snappy) {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }
}
