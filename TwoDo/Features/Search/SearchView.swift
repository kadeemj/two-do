import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.sortIndex) private var tasks: [TodoTask]
    @State private var query = ""
    @State private var selectedList: TaskSmartList = .all
    @State private var searchScope: TaskSearchScope = .everything
    @State private var editingTask: TodoTask?

    private var smartListTasks: [TodoTask] {
        selectedList.tasks(from: tasks)
    }

    private var results: [TodoTask] {
        TaskSearch.results(in: smartListTasks, query: query, scope: searchScope)
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                smartListsSection
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)

                if results.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                } else {
                    Section {
                        ForEach(results, id: \.id) { task in
                            TaskRow(task: task, showDragHandle: false) {
                                editingTask = task
                            }
                            .listRowInsets(EdgeInsets())
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    delete(task)
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                        }
                    } header: {
                        Text("\(selectedList.title) · \(results.count)")
                    }
                }
            }
            .listStyle(.plain)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search tasks, notes, projects, and tags"
            )
            .searchScopes($searchScope) {
                ForEach(TaskSearchScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .navigationTitle("Search")
            .sheet(item: $editingTask) { task in
                AddEditTaskView(mode: .edit(task))
            }
        }
    }

    private var smartListsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SMART LISTS")
                .font(TwoDoTypography.sectionHeader)
                .tracking(0.8)
                .padding(.horizontal, TwoDoSpacing.rowHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(TaskSmartList.allCases) { list in
                        Button {
                            withAnimation(.snappy) {
                                selectedList = list
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: list.systemImage)
                                    Spacer(minLength: 14)
                                    Text("\(list.tasks(from: tasks).count)")
                                        .font(.subheadline.monospacedDigit())
                                }
                                Text(list.title)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(selectedList == list ? .white : .primary)
                            .frame(width: 112, alignment: .leading)
                            .padding(12)
                            .background(
                                selectedList == list ? TwoDoColor.accentBlue : Color(.secondarySystemBackground),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(list.title), \(list.tasks(from: tasks).count) tasks")
                        .accessibilityAddTraits(selectedList == list ? .isSelected : [])
                    }
                }
                .padding(.horizontal, TwoDoSpacing.rowHorizontal)
            }
        }
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            trimmedQuery.isEmpty ? "No Tasks" : "No Results",
            systemImage: trimmedQuery.isEmpty ? selectedList.systemImage : "magnifyingglass",
            description: Text(
                trimmedQuery.isEmpty
                    ? "There are no tasks in this smart list."
                    : "Try another search term, scope, or smart list."
            )
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
    }

    private func delete(_ task: TodoTask) {
        withAnimation(.snappy) {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }
}
