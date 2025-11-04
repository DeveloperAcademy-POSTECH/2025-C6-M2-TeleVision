import Foundation

// MARK: - OperationAsset Entity

// Entity: lifecycle/stateful (CKAsset linkage, replacement/version possible)

public struct OperationAsset: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var fileURL: URL
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        fileURL: URL,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fileURL = fileURL
        self.createdAt = createdAt
    }
}
