import Foundation
import SwiftData
import UserNotifications

/// Schedules on-device (local) notifications for task due dates and time blocks.
///
/// Rather than tracking individual edits, the whole pending-notification set is
/// rebuilt from the store on every resync. That keeps notifications correct after
/// any mutation path — edits, completions, deletions, and changes that arrive via
/// CloudKit sync from the user's other devices.
@MainActor
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    /// Identifies requests owned by this scheduler so resync never touches
    /// notifications scheduled by anything else.
    private static let identifierPrefix = "twodo-task-"

    /// iOS keeps at most 64 pending local notifications per app; stay under it
    /// and prefer the soonest fire dates.
    private static let maxPending = 60

    private let center = UNUserNotificationCenter.current()
    private var pendingResync: Task<Void, Never>?

    func activate() {
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Debounced entry point so bursts of saves collapse into a single rebuild.
    func scheduleResync(container: ModelContainer) {
        pendingResync?.cancel()
        pendingResync = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await resync(container: container)
        }
    }

    func resync(container: ModelContainer) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional else { return }

        let descriptor = FetchDescriptor<TodoTask>(
            predicate: #Predicate { !$0.isCompleted }
        )
        guard let tasks = try? container.mainContext.fetch(descriptor) else { return }

        let now = Date.now
        var planned: [(fireAt: Date, request: UNNotificationRequest)] = []
        for task in tasks {
            for occurrence in TaskReminderPlan.occurrences(for: task, now: now) {
                planned.append((occurrence.fireAt, makeRequest(
                    id: "\(Self.identifierPrefix)\(task.id.uuidString)-\(occurrence.option.rawValue)",
                    title: task.title,
                    body: occurrence.body,
                    fireAt: occurrence.fireAt
                )))
            }
        }
        let requests = planned
            .sorted { $0.fireAt < $1.fireAt }
            .prefix(Self.maxPending)
            .map(\.request)

        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        for request in requests {
            try? await center.add(request)
        }
    }

    private func makeRequest(id: String, title: String, body: String, fireAt: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
