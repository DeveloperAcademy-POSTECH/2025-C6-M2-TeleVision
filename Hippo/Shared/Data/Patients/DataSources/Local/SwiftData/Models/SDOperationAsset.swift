import Foundation
import SwiftData

// MARK: - SDOperationAsset (SwiftData Model)

/// SwiftData model for OperationAsset entity
/// Primary Key: id (unique)
@Model
final class SDOperationAsset {
    @Attribute(.unique) var id: String
    var originalFileName: String
    @Attribute(.externalStorage) var bookmarkData: Data
    var createdAt: Date

    var operation: SDOperation?

    init(
        id: String,
        originalFileName: String,
        bookmarkData: Data,
        createdAt: Date = Date(),
        operation: SDOperation? = nil
    ) {
        self.id = id
        self.originalFileName = originalFileName
        self.bookmarkData = bookmarkData
        self.createdAt = createdAt
        self.operation = operation
    }

    // toDomain 매퍼 수정
    func toDomain() -> OperationAsset {
        OperationAsset(
            id: id,
            bookmarkData: bookmarkData,
            originalFileName: originalFileName,
            createdAt: createdAt
        )
    }
}
