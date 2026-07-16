import Foundation
import SwiftData

@Model
final class Tag {
    // CloudKit sync requires every attribute to be optional or have an
    // inline default value (initializer defaults don't count).
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    @Relationship(inverse: \TodoTask.tags)
    var tasks: [TodoTask]?

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}
