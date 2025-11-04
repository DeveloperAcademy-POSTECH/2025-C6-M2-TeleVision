import Foundation

/// Use Case for creating a new operation for a patient
public struct CreateOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: String
        public let command: CreateOperationCommand

        public init(patientID: String, command: CreateOperationCommand) {
            self.patientID = patientID
            self.command = command
        }
    }

    private let repository: OperationRepository

    public init(repository: OperationRepository) {
        self.repository = repository
    }

    /// Creates a new operation for the specified patient
    /// - Parameter input: Input containing patient ID and operation command
    /// - Throws: OperationError.patientNotFound if patient doesn't exist
    /// - Returns: The created Operation entity
    @discardableResult
    public func run(_ input: Input) async throws -> Operation {
        // Convert command to operation entity (UUID generated here)
        let newOperation = input.command.toOperation()

        // Create operation through repository
        return try await repository.createOperation(newOperation, forPatientID: input.patientID)
    }
}
