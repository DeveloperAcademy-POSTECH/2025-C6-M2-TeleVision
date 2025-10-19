import Foundation

public struct UpsertOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operation: Operation

    public init(patientID: String, operation: Operation) {
      self.patientID = patientID
      self.operation = operation
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    // Get patient, update operation, and update timestamp (business logic)
    var patient = try await repository.getPatient(id: input.patientID)

    if let operationIndex = patient.operations.firstIndex(where: { $0.id == input.operation.id }) {
      patient.operations[operationIndex] = input.operation
    } else {
      patient.operations.append(input.operation)
    }

    let updatedPatient = patient.withUpdatedTimestamp()
    _ = try await repository.upsertPatient(updatedPatient)
  }
}
