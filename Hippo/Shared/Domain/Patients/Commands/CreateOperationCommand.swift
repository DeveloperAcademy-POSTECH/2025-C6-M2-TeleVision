import Foundation

/// Command object for creating a new operation
/// Encapsulates all required parameters with validation
public struct CreateOperationCommand: Sendable {
    public let title: String
    public let diagnosis: String
    public let surgeon: String
    public let date: Date
    public let details: String
    public let assets: [OperationAsset]
    public let status: OperationStatus

    /// Creates a new operation command with validation
    /// - Parameters:
    ///   - title: Operation title (must not be empty)
    ///   - diagnosis: Patient diagnosis (must not be empty)
    ///   - surgeon: Surgeon name (must not be empty)
    ///   - date: Scheduled operation date
    ///   - details: Additional operation details
    ///   - assets: Associated operation assets
    ///   - status: Current operation status
    /// - Throws: `ValidationError` if any required field is invalid
    public init(
        title: String,
        diagnosis: String,
        surgeon: String,
        date: Date,
        details: String = "",
        assets: [OperationAsset] = [],
        status: OperationStatus = .planned
    ) throws {
        // Validation
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyField("title")
        }

        guard !diagnosis.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyField("diagnosis")
        }

        guard !surgeon.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyField("surgeon")
        }

        self.title = title.trimmingCharacters(in: .whitespaces)
        self.diagnosis = diagnosis.trimmingCharacters(in: .whitespaces)
        self.surgeon = surgeon.trimmingCharacters(in: .whitespaces)
        self.date = date
        self.details = details
        self.assets = assets
        self.status = status
    }

    /// Converts command to Operation entity
    /// - Returns: New Operation instance with generated UUID
    public func toOperation() async throws -> Operation {
        Operation(
            id: UUID().uuidString,
            title: title,
            diagnosis: diagnosis,
            surgeon: surgeon,
            date: date,
            details: details,
            operationAssets: assets,
            status: status
        )
    }
}
