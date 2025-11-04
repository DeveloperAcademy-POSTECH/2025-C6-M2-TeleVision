import Foundation

// MARK: - Operation Asset Display Model

/// View 레이어 전용 OperationAsset 모델
public struct OperationAssetDisplayModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let fileName: String
    public let fileURL: URL
    public let createdAt: Date

    /// 도메인 모델(OperationAsset)로부터 DisplayModel을 생성하는 매퍼(Mapper)
    public init(id: String, fileName: String, createdAt: Date, fileURL: URL) {
        self.id = id
        self.fileName = fileName
        self.createdAt = createdAt
        self.fileURL = fileURL
    }
}

public extension OperationAssetDisplayModel {
    func toDomain() -> OperationAsset {
        let bookmarkData = try? fileURL.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        return OperationAsset(
            id: id,
            bookmarkData: bookmarkData ?? Data(),
            originalFileName: fileName,
            createdAt: createdAt
        )
    }
}
