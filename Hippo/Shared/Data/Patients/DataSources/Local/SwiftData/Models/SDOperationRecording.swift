import Foundation
import SwiftData

// MARK: - SDOperationRecording (SwiftData Model)

/// SwiftData model for OperationRecording entity
/// Primary Key: id (unique)
@Model
final class SDOperationRecording {
    @Attribute(.unique) var id: String

    @Attribute(.externalStorage) var videoData: Data
    @Attribute(.externalStorage) var thumbnailData: Data?

    var createdAt: Date

    var operation: SDOperation?

    init(id: String, videoData: Data, thumbnailData: Data? = nil, createdAt: Date) {
        self.id = id
        self.videoData = videoData
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
    }
}
