import Foundation

public struct CaseID: Codable, Hashable, Sendable {
    public let value: String

    public init(value: String = UUID().uuidString) {
        self.value = value
    }
}

public struct Case: Codable, Sendable, Identifiable, Equatable {
    public let id: CaseID
    public var title: String
    public var diagnosis: String
    public var scheduledAt: Date?
    public var detail: String?
    public var models: [ModelFile]
    public var updatedAt: Date

    public init(
        id: CaseID = CaseID(),
        title: String,
        diagnosis: String,
        scheduledAt: Date? = nil,
        detail: String? = nil,
        models: [ModelFile] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.diagnosis = diagnosis
        self.scheduledAt = scheduledAt
        self.detail = detail
        self.models = models
        self.updatedAt = updatedAt
    }
}
