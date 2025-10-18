import Foundation

public struct OperationID: Codable, Hashable, Sendable {
    public let value: String

    public init(value: String = UUID().uuidString) {
        self.value = value
    }

    public nonisolated static func == (lhs: OperationID, rhs: OperationID) -> Bool {
        lhs.value == rhs.value
    }
}

public struct Operation: Codable, Sendable, Identifiable, Equatable {
    public let id: OperationID
    public var title: String
    public var diagnosis: String
    public var surgeon: String
    public var scheduledAt: Date?
    public var detail: String?
    public var operationAssets: [OperationAsset]
    public var updatedAt: Date

    public init(
        id: OperationID = OperationID(),
        title: String,
        diagnosis: String,
        surgeon: String,
        scheduledAt: Date? = nil,
        detail: String? = nil,
        operationAssets: [OperationAsset] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.diagnosis = diagnosis
        self.surgeon = surgeon
        self.scheduledAt = scheduledAt
        self.detail = detail
        self.operationAssets = operationAssets
        self.updatedAt = updatedAt
    }
}
