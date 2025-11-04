import Foundation

/// Use Case for updating an operation's status
public struct UpdateOperationStatus: Sendable {
    public struct Input: Sendable {
        public let patientID: String
        public let operationID: String
        public let status: OperationStatus

        public init(patientID: String, operationID: String, status: OperationStatus) {
            self.patientID = patientID
            self.operationID = operationID
            self.status = status
        }
    }

    private let repository: OperationRepository

    public init(repository: OperationRepository) {
        self.repository = repository
    }

    /// Updates an operation's status
    /// - Parameter input: Input containing patient ID, operation ID, and new status
    /// - Throws: OperationError.operationNotFound if operation doesn't exist
    /// - Throws: OperationError.patientNotFound if patient doesn't exist
    public func run(_ input: Input) async throws {
        try await repository.updateOperationStatus(
            operationID: input.operationID,
            inPatientID: input.patientID,
            status: input.status
        )
    }
}
