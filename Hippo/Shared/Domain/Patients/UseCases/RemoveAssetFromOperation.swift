import Foundation

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

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    // Get patient, remove asset, and update timestamp (business logic)
    var patient = try await repository.getPatient(id: input.patientID)

    guard let operationIndex = patient.operations.firstIndex(where: { $0.id == input.operationID }) else {
      throw UseCaseError.operationNotFound
    }

    patient.operations[operationIndex].operationAssets.removeAll { $0.id == input.assetID }

    let updatedPatient = patient.withUpdatedTimestamp()
    _ = try await repository.upsertPatient(updatedPatient)
  }
}
