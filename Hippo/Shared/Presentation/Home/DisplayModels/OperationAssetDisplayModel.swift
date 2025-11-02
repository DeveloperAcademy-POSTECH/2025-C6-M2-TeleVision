import Foundation

// MARK: - Operation Asset Display Model

/// View 레이어 전용 OperationAsset 모델
public struct OperationAssetDisplayModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let fileURL: URL
    public let createdAt: Date

    public init(
        id: String,
        name: String,
        fileURL: URL,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.createdAt = createdAt
    }
}
