import Foundation

/// Use Case for removing an asset from an operation
public struct RemoveAssetFromOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operationID: String
    public let assetID: String

    public init(patientID: String, operationID: String, assetID: String) {
      self.patientID = patientID
      self.operationID = operationID
      self.assetID = assetID
    }
  }

  private let repository: OperationRepository

  public init(repository: OperationRepository) {
    self.repository = repository
  }

  /// Removes an asset from an operation
  /// - Parameter input: Input containing patient ID, operation ID, and asset ID
  /// - Throws: OperationError.assetNotFound if asset doesn't exist
  /// - Throws: OperationError.operationNotFound if operation doesn't exist
  /// - Throws: OperationError.patientNotFound if patient doesn't exist
  public func run(_ input: Input) async throws {
    // Remove asset through repository
    try await repository.removeAsset(
      input.assetID,
      fromOperationID: input.operationID,
      inPatientID: input.patientID
    )
  }
}
