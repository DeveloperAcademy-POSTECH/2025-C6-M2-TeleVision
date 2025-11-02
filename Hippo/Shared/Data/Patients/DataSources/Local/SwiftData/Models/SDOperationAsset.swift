import Foundation
import SwiftData

// MARK: - SDOperationAsset (SwiftData Model)

/// SwiftData model for OperationAsset entity
/// Primary Key: id (unique)
@Model
final class SDOperationAsset {
    @Attribute(.unique) var id: String
    var name: String
    var fileURL: String // absolute URL string
    var createdAt: Date

    var operation: SDOperation?

    init(
        id: String,
        name: String,
        fileURL: String,
        createdAt: Date = Date(),
        operation: SDOperation? = nil
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.operation = operation
    }

    func toDomain() -> OperationAsset {
        OperationAsset(
            id: id,
            name: name,
            fileURL: URL(string: fileURL) ?? URL(fileURLWithPath: ""),
            createdAt: createdAt
        )
    }
}
