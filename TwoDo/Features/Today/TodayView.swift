import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.sortIndex) private var tasks: [TodoTask]
    @State private var editingTask: TodoTask?
    @State private var showingAdd = false
    @State private var sortByDue = true
    @State private var showingSearch = false

    private var overdue: [TodoTask] { TaskQueries.overdue(from: tasks) }
    private var today: [TodoTask] {
        let items = TaskQueries.today(from: tasks)
        if sortByDue {
            return items.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        }
        return items
    }
    private var timelineBlocks: [TimelineBlock] {
        TimelineLayout.blocks(from: tasks, on: .now)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        DayTimelineStrip(blocks: timelineBlocks)
                            .padding(.horizontal, TwoDoSpacing.rowHorizontal)
                            .padding(.bottom, 4)

                        if !overdue.isEmpty {
                            TaskSectionHeader(title: "Overdue", count: overdue.count, isOverdue: true)
                            LazyVStack(spacing: 0) {
                                ForEach(overdue, id: \.id) { task in
                                    SwipeToDeleteRow(onDelete: { delete(task) }) {
                                        TaskRow(task: task, isOverdue: true) {
                                            editingTask = task
                                        }
                                    }
                                    Divider()
                                        .padding(.leading, 48)
                                        .opacity(0.5)
                                }
                            }
                        }

                        TaskSectionHeader(title: "Today", count: today.count)
                        LazyVStack(spacing: 0) {
                            ForEach(today, id: \.id) { task in
                                SwipeToDeleteRow(onDelete: { delete(task) }) {
                                    TaskRow(task: task) {
                                        editingTask = task
                                    }
                                }
                                Divider()
                                    .padding(.leading, 48)
                                    .opacity(0.5)
                            }
                        }

                        Spacer(minLength: 100)
                    }
                }
                .background(Color(.systemBackground))

                fab
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button { sortByDue.toggle() } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 15, weight: .medium))
                        }
                        Menu {
                            Button("Due Date") { sortByDue = true }
                            Button("Manual") { sortByDue = false }
                        } label: {
                            HStack(spacing: 4) {
                                Text("Due Date")
                                    .font(.system(size: 14, weight: .medium))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                        Image(systemName: "sun.max")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditTaskView(mode: .create)
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(mode: .edit(task))
            }
            .sheet(isPresented: $showingSearch) {
                SearchView()
            }
        }
    }

    private func delete(_ task: TodoTask) {
        withAnimation(.snappy) {
            modelContext.delete(task)
            try? modelContext.save()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text("Today")
                    .font(TwoDoTypography.todayTitle)
                Spacer()
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(TwoDoColor.accentBlue)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TwoDoColor.accentBlue)
                Text(DateFormatting.dayHeader.string(from: .now))
                    .font(TwoDoTypography.dateSubtitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, TwoDoSpacing.rowHorizontal)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }

    private var fab: some View {
        Button {
            showingAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(TwoDoColor.accentBlue, in: Circle())
                .shadow(color: TwoDoColor.accentBlue.opacity(0.4), radius: 10, y: 5)
        }
        .padding(.trailing, 22)
        .padding(.bottom, 10)
        .accessibilityLabel("Add task")
    }
}

#Preview {
    TodayView()
        .modelContainer(ModelContainerFactory.makePreview())
}
