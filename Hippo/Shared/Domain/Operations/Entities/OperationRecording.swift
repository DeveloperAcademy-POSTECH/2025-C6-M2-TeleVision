import Foundation

// MARK: - OperationRecording Entity

// Entity: lifecycle/stateful (recording → upload/retry → thumbnail/retention)

public struct OperationRecording: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let videoData: Data
    public let thumbnailData: Data?
    public let createdAt: Date

    public init(id: String = UUID().uuidString, videoData: Data, thumbnailData: Data? = nil, createdAt: Date) {
        self.id = id
        self.videoData = videoData
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
    }
}
