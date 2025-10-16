import Foundation

public struct ModelID: Codable, Hashable, Sendable {
    public let value: String

    public init(value: String = UUID().uuidString) {
        self.value = value
    }

    public nonisolated static func == (lhs: ModelID, rhs: ModelID) -> Bool {
        lhs.value == rhs.value
    }
}

public enum ModelFormat: String, Codable, Sendable {
    case usdz
    case reality
    case obj
    case fbx
    case stl
    case dicom
}

public struct ModelFile: Codable, Sendable, Identifiable, Equatable {
    public let id: ModelID
    public var fileName: String
    public var format: ModelFormat
    public var sizeBytes: Int64?
    public var remoteURL: URL?
    public var localURL: URL?
    public var createdAt: Date

    public init(
        id: ModelID = ModelID(),
        fileName: String,
        format: ModelFormat,
        sizeBytes: Int64? = nil,
        remoteURL: URL? = nil,
        localURL: URL? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.format = format
        self.sizeBytes = sizeBytes
        self.remoteURL = remoteURL
        self.localURL = localURL
        self.createdAt = createdAt
    }
}
