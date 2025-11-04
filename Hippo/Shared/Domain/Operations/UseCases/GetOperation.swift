import Foundation

/// Use Case for retrieving a specific operation
public struct GetOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: String
        public let operationID: String

        public init(patientID: String, operationID: String) {
            self.patientID = patientID
            self.operationID = operationID
        }
    }

    private let repository: OperationRepository

    public init(repository: OperationRepository) {
        self.repository = repository
    }

    /// Retrieves a specific operation
    /// - Parameter input: Input containing patient ID and operation ID
    /// - Throws: OperationError.operationNotFound if operation doesn't exist
    /// - Throws: OperationError.patientNotFound if patient doesn't exist
    /// - Returns: The requested Operation
    public func run(_ input: Input) async throws -> Operation {
        try await repository.getOperation(id: input.operationID, inPatientID: input.patientID)
    }
}
