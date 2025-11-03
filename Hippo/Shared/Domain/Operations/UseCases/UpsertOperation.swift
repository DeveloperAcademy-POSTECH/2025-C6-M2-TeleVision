import Foundation

/// Use Case for upserting (creating or updating) an operation
public struct UpsertOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operation: Operation

    public init(patientID: String, operation: Operation) {
      self.patientID = patientID
      self.operation = operation
    }
  }

  private let repository: OperationRepository

  public init(repository: OperationRepository) {
    self.repository = repository
  }

  /// Upserts an operation (creates if new, updates if exists)
  /// - Parameter input: Input containing patient ID and operation
  /// - Throws: OperationError.patientNotFound if patient doesn't exist
  public func run(_ input: Input) async throws {
    // Update operation through repository
    try await repository.updateOperation(input.operation, inPatientID: input.patientID)
  }
}
