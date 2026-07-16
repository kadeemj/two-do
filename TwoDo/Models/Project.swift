import Foundation
import SwiftData

@Model
final class Project: Identifiable {
    // CloudKit sync requires every attribute to be optional or have an
    // inline default value (initializer defaults don't count).
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "3380F5"
    var sortIndex: Int = 0
    var createdAt: Date = Date.now

    @Relationship(deleteRule: .nullify, inverse: \TodoTask.project)
    var tasks: [TodoTask]?

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        sortIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}
