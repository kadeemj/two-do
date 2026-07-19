import SwiftUI
import WidgetKit

struct TwoDoTaskWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetConstants.widgetKind,
            intent: TaskWidgetConfigurationIntent.self,
            provider: TaskWidgetProvider()
        ) { entry in
            TaskWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Two Do Tasks")
        .description("See your focus, today, or upcoming tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct TwoDoWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TwoDoTaskWidget()
    }
}

#Preview("Focus Small", as: .systemSmall) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .focus,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Today Small", as: .systemSmall) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .today,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Upcoming Small", as: .systemSmall) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .upcoming,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Focus Medium", as: .systemMedium) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .focus,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Today Medium", as: .systemMedium) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .today,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Upcoming Medium", as: .systemMedium) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .upcoming,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Focus Large", as: .systemLarge) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .focus,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Today Large", as: .systemLarge) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .today,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Upcoming Large", as: .systemLarge) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .upcoming,
        snapshot: TaskWidgetPreview.snapshot
    )
}

#Preview("Overflow", as: .systemLarge) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .upcoming,
        snapshot: TaskWidgetPreview.overflowSnapshot
    )
}

#Preview("Empty", as: .systemSmall) {
    TwoDoTaskWidget()
} timeline: {
    TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .focus,
        snapshot: WidgetSnapshotEnvelope(generatedAt: TaskWidgetPreview.referenceDate, tasks: [])
    )
}

#Preview("Dark Small") {
    TaskWidgetEntryView(entry: TaskWidgetEntry(
        date: TaskWidgetPreview.referenceDate,
        mode: .focus,
        snapshot: TaskWidgetPreview.snapshot
    ))
    .environment(\.colorScheme, .dark)
    .frame(width: 170, height: 170)
}
