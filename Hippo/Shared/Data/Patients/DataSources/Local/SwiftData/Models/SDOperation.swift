import Foundation
import SwiftData

// MARK: - SDOperation (SwiftData Model)

/// SwiftData model for Operation entity
/// Primary Key: id (unique)
@Model
final class SDOperation {
    @Attribute(.unique) var id: String
    var title: String
    var diagnosis: String
    var surgeon: String
    var surgicalSite: String
    var date: Date
    var details: String
    var statusRaw: String // "planned" | "inProgress" | "completed" | "cancelled"

    var patient: SDPatient?

    @Relationship(deleteRule: .cascade)
    var assets: [SDOperationAsset] = []

    @Relationship(deleteRule: .cascade)
    var recordings: [SDOperationRecording] = []

    init(
        id: String,
        title: String,
        diagnosis: String,
        surgeon: String,
        surgicalSite: String,
        date: Date,
        details: String,
        statusRaw: String
    ) {
        self.id = id
        self.title = title
        self.diagnosis = diagnosis
        self.surgeon = surgeon
        self.surgicalSite = surgicalSite
        self.date = date
        self.details = details
        self.statusRaw = statusRaw
    }
}

extension SDOperation {
    func toDomain() -> Operation {
        Operation(
            id: id,
            title: title,
            diagnosis: diagnosis,
            surgeon: surgeon,
            surgicalSite: surgicalSite,
            date: date,
            details: details,
            operationAssets: assets.map { $0.toDomain() },
            recordings: [],
            status: OperationStatus(rawValue: statusRaw) ?? .planned
        )
    }
}
