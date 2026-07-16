import SwiftUI

enum TwoDoTypography {
    static let largeTitle = Font.system(.largeTitle, design: .default).weight(.bold)
    static let todayTitle = Font.system(size: 34, weight: .bold, design: .default)
    static let sectionHeader = Font.system(size: 13, weight: .semibold, design: .default)
    static let taskTitle = Font.system(size: 16, weight: .semibold, design: .default)
    static let taskTitleOverdue = Font.system(size: 16, weight: .semibold, design: .default)
    static let metadata = Font.system(size: 12, weight: .regular, design: .default)
    static let dateSubtitle = Font.system(size: 15, weight: .regular, design: .default)
    static let timelineCaption = Font.system(size: 13, weight: .medium, design: .default)
    static let scheduleBlockTitle = Font.system(size: 15, weight: .semibold, design: .default)
    static let freeTime = Font.system(size: 12, weight: .medium, design: .default)
}
