import Foundation

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

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    // Get patient, attach asset, and update timestamp (business logic)
    var patient = try await repository.getPatient(id: input.patientID)

    guard let operationIndex = patient.operations.firstIndex(where: { $0.id == input.operationID }) else {
      throw UseCaseError.operationNotFound
    }

    // Convert command to OperationAsset entity (UUID generated here)
    let newAsset = input.command.toOperationAsset()
    patient.operations[operationIndex].operationAssets.append(newAsset)

    let updatedPatient = patient.withUpdatedTimestamp()
    _ = try await repository.upsertPatient(updatedPatient)
  }
}

// MARK: - Errors

public enum UseCaseError: Error, LocalizedError {
  case operationNotFound

  public var errorDescription: String? {
    switch self {
    case .operationNotFound:
      return "Operation not found in patient's operations"
    }
  }
}
