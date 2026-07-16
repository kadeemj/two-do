import Foundation
import SwiftData

@Model
final class Tag {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(inverse: \TodoTask.tags)
    var tasks: [TodoTask]?

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
