import SwiftUI
import WidgetKit

struct TaskWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TaskWidgetEntry

    private var tasks: [WidgetTaskSnapshot] { entry.snapshot.tasks }
    private var mode: WidgetViewMode { entry.mode }
    private var focus: WidgetTaskSnapshot? {
        WidgetTaskSelection.focus(from: tasks, now: entry.date)
    }
    private var rows: [WidgetTaskSnapshot] {
        switch mode {
        case .focus:
            WidgetTaskSelection.following(focus: focus, from: tasks, now: entry.date)
        case .today:
            WidgetTaskSelection.today(from: tasks, now: entry.date)
        case .upcoming:
            WidgetTaskSelection.upcoming(from: tasks, now: entry.date)
        }
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallLayout
            case .systemMedium:
                mediumLayout
            case .systemLarge:
                largeLayout
            default:
                smallLayout
            }
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }

    private var smallLayout: some View {
        let primary = mode == .focus ? focus : rows.first
        return VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(mode: mode, count: mode == .focus ? nil : rows.count)

            if let primary {
                VStack(alignment: .leading, spacing: 5) {
                    TaskProjectLabel(task: primary)
                    Text(primary.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    TaskTimingLabel(task: primary, now: entry.date, prominent: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if mode == .focus, let next = rows.first {
                    Divider()
                    HStack(spacing: 5) {
                        Text("NEXT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                        Text(next.title)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                }
            } else {
                WidgetEmptyState()
            }
        }
        .widgetURL(primary.map { WidgetConstants.taskURL(id: $0.id) } ?? WidgetConstants.todayURL)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetHeader(mode: mode, count: mode == .focus ? nil : rows.count)

            Group {
                if mode == .focus, let focus {
                    HStack(spacing: 12) {
                        Link(destination: WidgetConstants.taskURL(id: focus.id)) {
                            FocusTaskCard(task: focus, now: entry.date)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        }
                        Divider()
                        TaskListSection(
                            title: "Up Next",
                            tasks: rows,
                            limit: 4,
                            now: entry.date
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                } else if mode == .focus || rows.isEmpty {
                    WidgetEmptyState()
                } else {
                    TaskListSection(
                        title: "Tasks",
                        tasks: rows,
                        limit: 4,
                        now: entry.date
                    )
                }
            }
        }
        .widgetURL(WidgetConstants.todayURL)
    }

    private var largeLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            WidgetHeader(mode: mode, count: mode == .focus ? nil : rows.count)

            if mode == .focus, let focus {
                Link(destination: WidgetConstants.taskURL(id: focus.id)) {
                    FocusTaskCard(task: focus, now: entry.date)
                }
                Divider()
                TaskListSection(title: "Up Next", tasks: rows, limit: 8, now: entry.date)
            } else if mode == .focus || rows.isEmpty {
                WidgetEmptyState()
            } else {
                TaskListSection(
                    title: mode.title,
                    tasks: rows,
                    limit: 8,
                    now: entry.date,
                    showsCount: true
                )
            }

        }
        .widgetURL(WidgetConstants.todayURL)
    }
}

private struct WidgetHeader: View {
    let mode: WidgetViewMode
    let count: Int?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: mode.symbolName)
                .foregroundStyle(Color.widgetBlue)
            Text(mode.title)
                .font(.system(size: 13, weight: .bold))
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            CreateTaskLink()
        }
    }
}

private struct CreateTaskLink: View {
    var body: some View {
        Link(destination: WidgetConstants.createTaskURL) {
            Image(systemName: "plus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.widgetBlue)
                .frame(width: 22, height: 22)
                .background(Color.widgetBlue.opacity(0.14), in: Circle())
        }
        .accessibilityLabel("Create task")
    }
}

private struct FocusTaskCard: View {
    let task: WidgetTaskSnapshot
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TaskProjectLabel(task: task)
            Text(task.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(2)
            TaskTimingLabel(task: task, now: now, prominent: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TaskListSection: View {
    let title: String
    let tasks: [WidgetTaskSnapshot]
    let limit: Int
    let now: Date
    var showsCount = false

    private var visibleTasks: ArraySlice<WidgetTaskSnapshot> { tasks.prefix(limit) }
    private var remaining: Int { max(0, tasks.count - visibleTasks.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                Spacer()
                if showsCount {
                    Text("\(tasks.count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if visibleTasks.isEmpty {
                Text("No tasks")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                ForEach(visibleTasks) { task in
                    Link(destination: WidgetConstants.taskURL(id: task.id)) {
                        TaskWidgetRow(task: task, now: now)
                    }
                }
                if remaining > 0 {
                    Text("+\(remaining) more")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.widgetBlue)
                }
            }
        }
    }
}

private struct TaskWidgetRow: View {
    let task: WidgetTaskSnapshot
    let now: Date

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: task.projectColorHex))
                .frame(width: 7, height: 7)
            Text(task.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            TaskTimingLabel(task: task, now: now, prominent: false)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

private struct TaskProjectLabel: View {
    let task: WidgetTaskSnapshot

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(hex: task.projectColorHex))
                .frame(width: 7, height: 7)
            Text(task.projectName ?? "Task")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if task.isFlagged {
                Image(systemName: "flag.fill")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.orange)
            }
        }
        .textCase(.uppercase)
    }
}

private struct TaskTimingLabel: View {
    let task: WidgetTaskSnapshot
    let now: Date
    let prominent: Bool

    var body: some View {
        Group {
            if let end = task.scheduledEnd,
               let start = task.scheduledStart,
               start <= now,
               now < end {
                HStack(spacing: 4) {
                    Text(end, style: .timer)
                        .monospacedDigit()
                    if prominent { Text("remaining") }
                }
                .foregroundStyle(Color.widgetBlue)
            } else if let start = task.scheduledStart, start > now {
                Text(start, style: .time)
            } else if WidgetTaskSelection.isOverdue(task, now: now) {
                Text("Overdue")
                    .foregroundStyle(.red)
            } else if let dueAt = task.dueAt {
                if Calendar.current.isDate(dueAt, inSameDayAs: now) {
                    Text("Due today")
                } else {
                    Text(dueAt, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                }
            }
        }
        .font(.system(size: prominent ? 12 : 9, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct WidgetEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22))
                .foregroundStyle(Color.widgetBlue)
            Text("You're all caught up")
                .font(.system(size: 13, weight: .semibold))
            Text("Open T2Do to add a task.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private extension WidgetViewMode {
    var title: String {
        switch self {
        case .focus: "Focus"
        case .today: "Today"
        case .upcoming: "Upcoming"
        }
    }

    var symbolName: String {
        switch self {
        case .focus: "scope"
        case .today: "checklist"
        case .upcoming: "calendar"
        }
    }
}

private extension Color {
    static let widgetBlue = Color(red: 0.20, green: 0.50, blue: 0.96)

    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(sanitized, radix: 16) ?? 0x3380F5
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
