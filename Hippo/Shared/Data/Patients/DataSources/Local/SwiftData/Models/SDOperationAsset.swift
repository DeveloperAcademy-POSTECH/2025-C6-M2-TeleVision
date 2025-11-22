import Foundation
import SwiftData

// MARK: - SDOperationAsset (SwiftData Model)

/// SwiftData model for OperationAsset entity
/// Primary Key: id (unique)
/// CloudKit 동기화를 위해 파일 데이터를 직접 저장
@Model
final class SDOperationAsset {
    var id: String = UUID().uuidString
    var originalFileName: String = ""
    
    // CloudKit 동기화를 위해 실제 파일 데이터를 저장
    @Attribute(.externalStorage) var fileData: Data = Data()
    var createdAt: Date = Date()

    var operation: SDOperation?

    init(
        id: String,
        originalFileName: String,
        fileData: Data,
        createdAt: Date = Date(),
        operation: SDOperation? = nil
    ) {
        self.id = id
        self.originalFileName = originalFileName
        self.fileData = fileData
        self.createdAt = createdAt
        self.operation = operation
    }

    // toDomain 매퍼 수정
    func toDomain() -> OperationAsset {
        OperationAsset(
            id: id,
            fileData: fileData,
            originalFileName: originalFileName,
            createdAt: createdAt
        )
    }
}
