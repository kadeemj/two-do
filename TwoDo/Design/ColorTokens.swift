import SwiftUI

enum TwoDoColor {
    static let overdue = Color(red: 0.93, green: 0.35, blue: 0.32)
    static let accentBlue = Color(red: 0.20, green: 0.48, blue: 0.96)
    static let timelineNeedle = Color(red: 0.95, green: 0.25, blue: 0.28)
    static let metadata = Color.secondary
    static let freeTime = Color.secondary.opacity(0.7)

    static let projectOrange = Color(red: 0.96, green: 0.55, blue: 0.22)
    static let projectBlue = Color(red: 0.35, green: 0.62, blue: 0.95)
    static let projectYellow = Color(red: 0.95, green: 0.78, blue: 0.25)
    static let projectPurple = Color(red: 0.62, green: 0.48, blue: 0.90)
    static let projectGreen = Color(red: 0.45, green: 0.72, blue: 0.35)
    static let projectCoral = Color(red: 0.95, green: 0.42, blue: 0.38)

    static func project(from hex: String) -> Color {
        Color(hex: hex) ?? accentBlue
    }
}

extension Color {
    init?(hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #else
        return "3380F5"
        #endif
    }
}

enum TwoDoSpacing {
    static let rowHorizontal: CGFloat = 16
    static let sectionHeaderTop: CGFloat = 20
    static let timelineHeight: CGFloat = 28
    static let colorStripeWidth: CGFloat = 3
    static let scheduleHourHeight: CGFloat = 56
}
