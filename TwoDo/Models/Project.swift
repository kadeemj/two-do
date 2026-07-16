import Foundation
import SwiftData

@Model
final class Project: Identifiable {
    var id: UUID
    var name: String
    var colorHex: String
    var sortIndex: Int
    var createdAt: Date

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
