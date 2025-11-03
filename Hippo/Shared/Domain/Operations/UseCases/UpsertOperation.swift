import Foundation

/// Use Case for updating an existing operation
public struct UpsertOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: String
        public let command: UpdateOperationCommand

        public init(patientID: String, command: UpdateOperationCommand) {
            self.patientID = patientID
            self.command = command
        }
    }

    private let repository: OperationRepository

    public init(repository: OperationRepository) {
        self.repository = repository
    }

    /// Updates an operation with the provided command
    /// - Parameter input: Input containing patient ID and update command
    /// - Throws: OperationError.patientNotFound if patient doesn't exist
    /// - Throws: OperationError.operationNotFound if operation doesn't exist
    public func run(_ input: Input) async throws {
        // 1. Retrieve existing operation
        let existingOperation = try await repository.getOperation(
            id: input.command.operationID,
            inPatientID: input.patientID
        )

        // 2. Apply command updates to existing operation
        let updatedOperation = input.command.applyTo(existingOperation)

        // 3. Update operation through repository
        try await repository.updateOperation(updatedOperation, inPatientID: input.patientID)
    }
}
