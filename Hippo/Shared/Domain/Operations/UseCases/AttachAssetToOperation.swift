import Foundation

/// Use Case for attaching a single asset to an operation
public struct AttachAssetToOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operationID: String
    public let command: AttachAssetCommand

    public init(patientID: String, operationID: String, command: AttachAssetCommand) {
      self.patientID = patientID
      self.operationID = operationID
      self.command = command
    }
  }

  private let repository: OperationRepository

  public init(repository: OperationRepository) {
    self.repository = repository
  }

  /// Attaches a single asset to an operation
  /// - Parameter input: Input containing patient ID, operation ID, and asset command
  /// - Throws: OperationError.operationNotFound if operation doesn't exist
  /// - Throws: OperationError.patientNotFound if patient doesn't exist
  public func run(_ input: Input) async throws {
    // Convert command to OperationAsset entity (UUID generated here)
    let newAsset = input.command.toOperationAsset()

    // Add asset through repository
    try await repository.addAssets(
      [newAsset],
      toOperationID: input.operationID,
      inPatientID: input.patientID
    )
  }
}
