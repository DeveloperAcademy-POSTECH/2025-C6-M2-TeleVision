import Foundation

// MARK: - Operation Display Model

/// View 레이어 전용 Operation 모델
public struct OperationDisplayModel: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let diagnosis: String
    public let surgeon: String
    public let surgicalSite: String
    public let date: Date
    public let dateText: String
    public let details: String
    public let status: OperationStatus
    public let assets: [OperationAssetDisplayModel]
    public let assetCount: Int

    public init(
        id: String,
        title: String,
        diagnosis: String,
        surgeon: String,
        surgicalSite: String,
        date: Date,
        dateText: String,
        details: String,
        status: OperationStatus,
        assets: [OperationAssetDisplayModel],
        assetCount: Int
    ) {
        self.id = id
        self.title = title
        self.diagnosis = diagnosis
        self.surgeon = surgeon
        self.surgicalSite = surgicalSite
        self.date = date
        self.dateText = dateText
        self.details = details
        self.status = status
        self.assets = assets
        self.assetCount = assetCount
    }

    // MOCK Data
    public static let MockData = OperationDisplayModel(
        id: "operation-001",
        title: "Appendectomy",
        diagnosis: "Acute Appendicitis",
        surgeon: "Dr. John Doe",
        surgicalSite: "Lower Right Abdomen",
        date: Date(),
        dateText: "2024.06.15",
        details: "Laparoscopic appendectomy performed successfully without complications.",
        status: .completed,
        assets: [],
        assetCount: 0
    )
}
