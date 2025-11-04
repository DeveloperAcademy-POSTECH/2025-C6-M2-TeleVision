import Foundation

/// Command object for updating an existing operation
/// Encapsulates update parameters with validation
/// Only non-nil fields will be updated
public struct UpdateOperationCommand: Sendable {
    public let operationID: String
    public let title: String?
    public let diagnosis: String?
    public let surgeon: String?
    public let date: Date?
    public let details: String?
    public let status: OperationStatus?

    /// Creates an update operation command with validation
    /// - Parameters:
    ///   - operationID: ID of the operation to update (required)
    ///   - title: New operation title (optional)
    ///   - diagnosis: New patient diagnosis (optional)
    ///   - surgeon: New surgeon name (optional)
    ///   - date: New scheduled operation date (optional)
    ///   - details: New operation details (optional)
    ///   - status: New operation status (optional)
    /// - Throws: `ValidationError` if operationID is empty or all update fields are nil
    public init(
        operationID: String,
        title: String? = nil,
        diagnosis: String? = nil,
        surgeon: String? = nil,
        date: Date? = nil,
        details: String? = nil,
        status: OperationStatus? = nil
    ) throws {
        // Validate operation ID
        guard !operationID.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw ValidationError.emptyField("operationID")
        }

        // At least one field must be provided for update
        guard title != nil || diagnosis != nil || surgeon != nil ||
              date != nil || details != nil || status != nil else {
            throw ValidationError.invalidField("update", "At least one field must be provided for update")
        }

        // Validate and trim string fields if present
        if let title = title {
            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError.emptyField("title")
            }
            self.title = title.trimmingCharacters(in: .whitespaces)
        } else {
            self.title = nil
        }

        if let diagnosis = diagnosis {
            guard !diagnosis.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError.emptyField("diagnosis")
            }
            self.diagnosis = diagnosis.trimmingCharacters(in: .whitespaces)
        } else {
            self.diagnosis = nil
        }

        if let surgeon = surgeon {
            guard !surgeon.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw ValidationError.emptyField("surgeon")
            }
            self.surgeon = surgeon.trimmingCharacters(in: .whitespaces)
        } else {
            self.surgeon = nil
        }

        self.operationID = operationID.trimmingCharacters(in: .whitespaces)
        self.date = date
        self.details = details
        self.status = status
    }

    /// Applies this command's updates to an existing operation
    /// Only non-nil fields are updated
    /// - Parameter operation: The existing operation to update
    /// - Returns: Updated Operation instance
    public func applyTo(_ operation: Operation) -> Operation {
        Operation(
            id: operation.id,
            title: title ?? operation.title,
            diagnosis: diagnosis ?? operation.diagnosis,
            surgeon: surgeon ?? operation.surgeon,
            date: date ?? operation.date,
            details: details ?? operation.details,
            operationAssets: operation.operationAssets,
            recordings: operation.recordings,
            status: status ?? operation.status
        )
    }
}
