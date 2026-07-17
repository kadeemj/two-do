import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoTask.sortIndex) private var tasks: [TodoTask]
    @State private var editingTask: TodoTask?
    @State private var showingAdd = false
    @State private var googleEvents = GoogleCalendarEventsService()
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    @State private var showingDayPicker = false

    private var isToday: Bool { Calendar.current.isDateInToday(selectedDay) }
    private var overdue: [TodoTask] { TaskQueries.overdue(from: tasks) }
    private var allDayTasks: [TodoTask] { TaskQueries.dateOnly(on: selectedDay, from: tasks) }
    private var timelineBlocks: [TimelineBlock] {
        TimelineLayout.merged(
            TimelineLayout.blocks(from: tasks, on: selectedDay),
            TimelineLayout.blocks(from: googleEvents.timedEvents, on: selectedDay)
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        header

                        if !googleEvents.allDayEvents.isEmpty || !allDayTasks.isEmpty {
                            allDayRow
                                .padding(.horizontal, TwoDoSpacing.rowHorizontal)
                                .padding(.bottom, 12)
                        }

                        DayTimelineStrip(blocks: timelineBlocks, dayStartHour: 6, dayEndHour: 23, showCaption: isToday, showNow: isToday)
                            .padding(.horizontal, TwoDoSpacing.rowHorizontal)
                            .padding(.bottom, 18)

                        HourlyScheduleView(blocks: timelineBlocks)
                            .padding(.bottom, 12)

                        if isToday && !overdue.isEmpty {
                            TaskSectionHeader(title: "Overdue", count: overdue.count, isOverdue: true)
                            LazyVStack(spacing: 0) {
                                ForEach(overdue, id: \.id) { task in
                                    SwipeToDeleteRow(onDelete: { delete(task) }) {
                                        TaskRow(task: task, isOverdue: true, showDragHandle: false) {
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
                .refreshable {
                    await googleEvents.loadEvents(for: selectedDay)
                }

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
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAdd) {
                AddEditTaskView(mode: .create)
            }
            .sheet(item: $editingTask) { task in
                AddEditTaskView(mode: .edit(task))
            }
            .sheet(isPresented: $showingDayPicker) {
                dayPickerSheet
            }
            .task(id: selectedDay) {
                await googleEvents.loadEvents(for: selectedDay)
            }
        }
    }

    private var allDayRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allDayTasks, id: \.id) { task in
                    Button {
                        editingTask = task
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "circle")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(TwoDoColor.project(from: task.project?.colorHex ?? "3380F5"))
                            Text(task.title)
                                .font(TwoDoTypography.metadata)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                ForEach(googleEvents.allDayEvents) { event in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(TwoDoColor.project(from: event.colorHex))
                            .frame(width: 7, height: 7)
                        Text(event.title)
                            .font(TwoDoTypography.metadata)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.06), in: Capsule())
                }
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
        HStack(alignment: .top, spacing: 12) {
            Button {
                showingDayPicker = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(DateFormatting.shortDay.string(from: selectedDay))
                        .font(TwoDoTypography.dateSubtitle)
                        .foregroundStyle(.secondary)
                    Text(dayTitle)
                        .font(TwoDoTypography.todayTitle)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pick a day")

            Spacer()

            HStack(spacing: 10) {
                dayChevron("chevron.left", days: -1)
                dayChevron("chevron.right", days: 1)
            }
            .padding(.top, 6)
        }
        .padding(.horizontal, TwoDoSpacing.rowHorizontal)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .animation(.snappy, value: selectedDay)
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDay) { return "Today" }
        if calendar.isDateInTomorrow(selectedDay) { return "Tomorrow" }
        if calendar.isDateInYesterday(selectedDay) { return "Yesterday" }
        return DateFormatting.weekday.string(from: selectedDay)
    }

    private func dayChevron(_ systemName: String, days: Int) -> some View {
        Button {
            shiftDay(by: days)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(days < 0 ? "Previous day" : "Next day")
    }

    private func shiftDay(by days: Int) {
        let calendar = Calendar.current
        if let day = calendar.date(byAdding: .day, value: days, to: selectedDay) {
            selectedDay = calendar.startOfDay(for: day)
        }
    }

    private var dayPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("Day", selection: $selectedDay, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, 12)
                Spacer(minLength: 0)
            }
            .navigationTitle("Pick a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Today") {
                        selectedDay = Calendar.current.startOfDay(for: .now)
                        showingDayPicker = false
                    }
                    .disabled(isToday)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingDayPicker = false }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: selectedDay) { _, _ in
                showingDayPicker = false
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ScheduleView()
        .modelContainer(ModelContainerFactory.makePreview())
}
