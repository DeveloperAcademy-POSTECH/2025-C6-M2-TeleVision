import Foundation

public struct DeleteOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operationID: String

    public init(patientID: String, operationID: String) {
      self.patientID = patientID
      self.operationID = operationID
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    // Get patient, remove operation, and update timestamp (business logic)
    var patient = try await repository.getPatient(id: input.patientID)
    patient.operations.removeAll { $0.id == input.operationID }

    let updatedPatient = patient.withUpdatedTimestamp()
    _ = try await repository.upsertPatient(updatedPatient)
  }
}
