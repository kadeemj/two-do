import Foundation

enum DateFormatting {
    static let dayHeader: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, d MMMM"
        return f
    }()

    static let shortDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMM"
        return f
    }()

    static let time: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    static func relativeDue(_ date: Date, relativeTo now: Date = .now, calendar: Calendar = .current) -> String {
        let startToday = calendar.startOfDay(for: now)
        let startDue = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startDue, to: startToday).day ?? 0

        if days > 1 {
            return "\(days) days ago"
        } else if days == 1 {
            return "Yesterday"
        } else if days == 0 {
            return "Today, \(time.string(from: date))"
        } else if days == -1 {
            return "Tomorrow, \(time.string(from: date))"
        } else {
            let f = DateFormatter()
            f.dateFormat = "MMM d"
            return f.string(from: date)
        }
    }

    static func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) m" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h) h" }
        return "\(h) h \(m) m"
    }

    static func freeTimeLabel(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min free" }
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 {
            return h == 1 ? "1 hour free" : "\(h) hours free"
        }
        return "\(h) h \(m) m free"
    }
}
