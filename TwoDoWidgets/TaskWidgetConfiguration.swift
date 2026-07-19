import AppIntents

enum WidgetViewMode: String, AppEnum {
    case focus
    case today
    case upcoming

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Task View"

    static let caseDisplayRepresentations: [WidgetViewMode: DisplayRepresentation] = [
        .focus: "Focus",
        .today: "Today",
        .upcoming: "Upcoming"
    ]
}

struct TaskWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Task View"
    static let description = IntentDescription("Choose which tasks Two Do shows.")

    @Parameter(title: "View", default: .focus)
    var viewMode: WidgetViewMode

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$viewMode
        }
    }
}
