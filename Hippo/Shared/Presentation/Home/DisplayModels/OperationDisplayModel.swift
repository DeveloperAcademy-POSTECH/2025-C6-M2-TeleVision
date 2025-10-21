import Foundation

// MARK: - Operation Display Model

/// View 레이어 전용 Operation 모델
public struct OperationDisplayModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let diagnosis: String
    public let surgeon: String
    public let date: Date
    public let dateText: String
    public let details: String
    public let status: OperationStatus
    public let statusText: String
    public let statusColor: String
    public let assets: [OperationAssetDisplayModel]
    public let assetCount: Int

    public init(
        id: String,
        title: String,
        diagnosis: String,
        surgeon: String,
        date: Date,
        dateText: String,
        details: String,
        status: OperationStatus,
        statusText: String,
        statusColor: String,
        assets: [OperationAssetDisplayModel],
        assetCount: Int
    ) {
        self.id = id
        self.title = title
        self.diagnosis = diagnosis
        self.surgeon = surgeon
        self.date = date
        self.dateText = dateText
        self.details = details
        self.status = status
        self.statusText = statusText
        self.statusColor = statusColor
        self.assets = assets
        self.assetCount = assetCount
    }
}
