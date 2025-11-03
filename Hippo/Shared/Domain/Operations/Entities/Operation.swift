import Foundation

// MARK: - Operation Entity

public struct Operation: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var diagnosis: String
    public var surgeon: String
    public var date: Date
    public var details: String
    public var operationAssets: [OperationAsset]
    public var recordings: [OperationRecording]
    public var status: OperationStatus

    public init(
        id: String,
        title: String,
        diagnosis: String,
        surgeon: String,
        date: Date,
        details: String,
        operationAssets: [OperationAsset] = [],
        recordings: [OperationRecording] = [],
        status: OperationStatus
    ) {
        self.id = id
        self.title = title
        self.diagnosis = diagnosis
        self.surgeon = surgeon
        self.date = date
        self.details = details
        self.operationAssets = operationAssets
        self.recordings = recordings
        self.status = status
    }
}
