import Foundation
import Observation

enum AppTab: Hashable {
    case today
    case schedule
    case search
    case settings
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    var requestedTaskID: UUID?
    var requestedCreateTask = false

    @discardableResult
    func handle(url: URL) -> Bool {
        guard let deepLink = TwoDoDeepLink(url: url) else { return false }
        selectedTab = .today

        switch deepLink {
        case .today:
            requestedTaskID = nil
            requestedCreateTask = false
        case .createTask:
            requestedTaskID = nil
            requestedCreateTask = true
        case .task(let id):
            requestedTaskID = id
            requestedCreateTask = false
        }
        return true
    }
}
