import WidgetKit

struct TaskWidgetEntry: TimelineEntry {
    let date: Date
    let mode: WidgetViewMode
    let snapshot: WidgetSnapshotEnvelope
}

struct TaskWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TaskWidgetEntry {
        return TaskWidgetEntry(
            date: TaskWidgetPreview.referenceDate,
            mode: .focus,
            snapshot: TaskWidgetPreview.snapshot
        )
    }

    func snapshot(
        for configuration: TaskWidgetConfigurationIntent,
        in context: Context
    ) async -> TaskWidgetEntry {
        return TaskWidgetEntry(
            date: .now,
            mode: configuration.viewMode,
            snapshot: context.isPreview ? TaskWidgetPreview.snapshot : currentSnapshot
        )
    }

    func timeline(
        for configuration: TaskWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<TaskWidgetEntry> {
        let now = Date.now
        let snapshot = currentSnapshot
        let transitionDates = WidgetTaskSelection.transitionDates(from: snapshot.tasks, now: now)
        let entries = ([now] + transitionDates).map {
            TaskWidgetEntry(date: $0, mode: configuration.viewMode, snapshot: snapshot)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    private var currentSnapshot: WidgetSnapshotEnvelope {
        WidgetSnapshotStore.load() ?? WidgetSnapshotEnvelope(generatedAt: .now, tasks: [])
    }
}

enum TaskWidgetPreview {
    static let referenceDate: Date = {
        Calendar(identifier: .gregorian).date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 18,
            hour: 10,
            minute: 15
        ))!
    }()

    static let snapshot: WidgetSnapshotEnvelope = {
        let calendar = Calendar(identifier: .gregorian)
        func date(day: Int = 18, hour: Int = 9, minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(
                year: 2026,
                month: 7,
                day: day,
                hour: hour,
                minute: minute
            ))!
        }

        let tasks = [
            WidgetTaskSnapshot(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                title: "Finish product brief",
                dueAt: date(),
                scheduledStart: date(hour: 10),
                scheduledEnd: date(hour: 11),
                projectName: "Work",
                projectColorHex: "F58C38",
                isFlagged: true,
                sortIndex: 0
            ),
            WidgetTaskSnapshot(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                title: "Call with Jeremy",
                dueAt: date(),
                scheduledStart: date(hour: 11, minute: 30),
                scheduledEnd: date(hour: 12),
                projectName: "Personal",
                projectColorHex: "598FE8",
                isFlagged: false,
                sortIndex: 1
            ),
            WidgetTaskSnapshot(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                title: "Review launch checklist",
                dueAt: date(),
                scheduledStart: date(hour: 14),
                scheduledEnd: date(hour: 14, minute: 45),
                projectName: "Work",
                projectColorHex: "8BC85A",
                isFlagged: false,
                sortIndex: 2
            ),
            WidgetTaskSnapshot(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                title: "Pick up groceries",
                dueAt: date(day: 19),
                scheduledStart: nil,
                scheduledEnd: nil,
                projectName: "Errands",
                projectColorHex: "F2C73F",
                isFlagged: false,
                sortIndex: 3
            ),
            WidgetTaskSnapshot(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                title: "Renew passport",
                dueAt: date(day: 22),
                scheduledStart: nil,
                scheduledEnd: nil,
                projectName: "Personal",
                projectColorHex: "9E7AE6",
                isFlagged: true,
                sortIndex: 4
            )
        ]
        return WidgetSnapshotEnvelope(generatedAt: referenceDate, tasks: tasks)
    }()

    static let overflowSnapshot: WidgetSnapshotEnvelope = {
        let calendar = Calendar(identifier: .gregorian)
        let tasks = (1...12).map { index in
            let dueAt = calendar.date(byAdding: .day, value: index, to: referenceDate)
            return WidgetTaskSnapshot(
                id: UUID(uuidString: String(format: "10000000-0000-0000-0000-%012d", index))!,
                title: "Upcoming task \(index)",
                dueAt: dueAt,
                scheduledStart: nil,
                scheduledEnd: nil,
                projectName: index.isMultiple(of: 2) ? "Work" : "Personal",
                projectColorHex: index.isMultiple(of: 2) ? "F58C38" : "598FE8",
                isFlagged: index.isMultiple(of: 3),
                sortIndex: Double(index)
            )
        }
        return WidgetSnapshotEnvelope(generatedAt: referenceDate, tasks: tasks)
    }()
}
