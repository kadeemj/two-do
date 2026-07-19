import Foundation

enum WidgetConstants {
    static let appGroupIdentifier = "group.com.kadeem.twodo"
    static let snapshotKey = "twoDo.widget.tasks.v1"
    static let widgetKind = "com.kadeem.twodo.tasks"

    static let todayURL = URL(string: "twodo://today")!
    static let createTaskURL = URL(string: "twodo://create-task")!

    static func taskURL(id: UUID) -> URL {
        URL(string: "twodo://task/\(id.uuidString)")!
    }
}

struct WidgetTaskSnapshot: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let dueAt: Date?
    let scheduledStart: Date?
    let scheduledEnd: Date?
    let projectName: String?
    let projectColorHex: String
    let isFlagged: Bool
    let sortIndex: Double
}

struct WidgetSnapshotEnvelope: Codable, Equatable, Sendable {
    let generatedAt: Date
    let tasks: [WidgetTaskSnapshot]
}

enum WidgetSnapshotStore {
    static func load(defaults: UserDefaults? = nil) -> WidgetSnapshotEnvelope? {
        let defaults = defaults ?? UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
        guard
            let data = defaults?.data(forKey: WidgetConstants.snapshotKey),
            let envelope = try? JSONDecoder().decode(WidgetSnapshotEnvelope.self, from: data)
        else {
            return nil
        }
        return envelope
    }

    @discardableResult
    static func save(_ envelope: WidgetSnapshotEnvelope, defaults: UserDefaults? = nil) -> Bool {
        let defaults = defaults ?? UserDefaults(suiteName: WidgetConstants.appGroupIdentifier)
        guard let defaults, let data = try? JSONEncoder().encode(envelope) else { return false }
        defaults.set(data, forKey: WidgetConstants.snapshotKey)
        return true
    }
}

enum TwoDoDeepLink: Equatable {
    case today
    case createTask
    case task(UUID)

    init?(url: URL) {
        guard url.scheme?.lowercased() == "twodo" else { return nil }

        switch url.host?.lowercased() {
        case "today":
            self = .today
        case "create-task":
            self = .createTask
        case "task":
            let identifier = url.pathComponents.dropFirst().first
            guard let identifier, let id = UUID(uuidString: identifier) else { return nil }
            self = .task(id)
        default:
            return nil
        }
    }
}
