import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.sortIndex) private var tasks: [TodoTask]
    @Binding private var requestedTaskID: UUID?
    @Binding private var requestedCreateTask: Bool
    @State private var editingTask: TodoTask?
    @State private var showingAdd = false
    @State private var sortByDue = true
    @State private var showingSearch = false
    @State private var quickCaptureTitle = ""
    @FocusState private var isQuickCaptureFocused: Bool

    private var overdue: [TodoTask] { TaskQueries.overdue(from: tasks) }
    private var today: [TodoTask] {
        let items = TaskQueries.today(from: tasks)
        if sortByDue {
            return items.sorted { ($0.dueAt ?? .distantFuture) < ($1.dueAt ?? .distantFuture) }
        }
        return items
    }
    private var upcoming: [TodoTask] { TaskQueries.upcoming(from: tasks) }
    private var undated: [TodoTask] { TaskQueries.undated(from: tasks) }
    private var timelineBlocks: [TimelineBlock] {
        TimelineLayout.blocks(from: tasks, on: .now)
    }

    init(
        requestedTaskID: Binding<UUID?> = .constant(nil),
        requestedCreateTask: Binding<Bool> = .constant(false)
    ) {
        _requestedTaskID = requestedTaskID
        _requestedCreateTask = requestedCreateTask
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

                        if !upcoming.isEmpty {
                            TaskSectionHeader(title: "Upcoming", count: upcoming.count)
                            LazyVStack(spacing: 0) {
                                ForEach(upcoming, id: \.id) { task in
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
                        }

                        if !undated.isEmpty {
                            TaskSectionHeader(title: "No date", count: undated.count)
                            LazyVStack(spacing: 0) {
                                ForEach(undated, id: \.id) { task in
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
                        }

                        Spacer(minLength: 100)
                    }
                }
                .background(Color(.systemBackground))

            }
            .safeAreaInset(edge: .bottom) {
                quickCaptureBar
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
            .onChange(of: requestedTaskID, initial: true) { _, _ in
                presentRequestedTaskIfAvailable()
            }
            .onChange(of: requestedCreateTask, initial: true) { _, shouldPresent in
                presentCreateTaskIfRequested(shouldPresent)
            }
            .onChange(of: tasks.map(\.id)) { _, _ in
                presentRequestedTaskIfAvailable()
            }
        }
    }

    private func presentRequestedTaskIfAvailable() {
        guard let requestedTaskID else { return }
        editingTask = tasks.first { $0.id == requestedTaskID }
        self.requestedTaskID = nil
    }

    private func presentCreateTaskIfRequested(_ shouldPresent: Bool) {
        guard shouldPresent else { return }
        editingTask = nil
        showingAdd = true
        requestedCreateTask = false
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
                Text("Tasks")
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

    private var quickCaptureBar: some View {
        HStack(spacing: 10) {
            Button {
                showingAdd = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TwoDoColor.accentBlue)
                    .frame(width: 34, height: 34)
            }
            .accessibilityLabel("Add")

            TextField("Quickly add a task", text: $quickCaptureTitle)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($isQuickCaptureFocused)
                .onSubmit(captureQuickTask)

            Button(action: captureQuickTask) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(
                        quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : TwoDoColor.accentBlue
                    )
            }
            .disabled(quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Add task")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func captureQuickTask() {
        let title = quickCaptureTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        do {
            try TaskCapture.create(title: title, in: modelContext)
            quickCaptureTitle = ""
            CaptureTaskDonation.donate(title: title)
        } catch {
            return
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(ModelContainerFactory.makePreview())
}
