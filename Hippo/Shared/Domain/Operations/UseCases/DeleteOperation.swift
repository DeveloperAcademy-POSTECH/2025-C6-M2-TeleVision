import Foundation

/// Use Case for deleting an operation
public struct DeleteOperation: Sendable {
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

  /// Deletes an operation from a patient
  /// - Parameter input: Input containing patient ID and operation ID
  /// - Throws: OperationError.operationNotFound if operation doesn't exist
  /// - Throws: OperationError.patientNotFound if patient doesn't exist
  public func run(_ input: Input) async throws {
    // Delete operation through repository
    try await repository.deleteOperation(id: input.operationID, fromPatientID: input.patientID)
  }
}
