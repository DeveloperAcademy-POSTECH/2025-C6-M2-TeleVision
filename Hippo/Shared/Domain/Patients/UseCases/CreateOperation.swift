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

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  /// Creates a new operation for the specified patient
  /// - Parameter input: Input containing patient ID and operation command
  /// - Throws: Repository errors or patient not found error
  /// - Returns: The created Operation entity
  @discardableResult
  public func run(_ input: Input) async throws -> Operation {
    // Get patient
    var patient = try await repository.getPatient(id: input.patientID)

    // Convert command to operation entity (UUID generated here)
    let newOperation = input.command.toOperation()

    // Add operation to patient
    patient.operations.append(newOperation)

    // Update patient with new timestamp
    let updatedPatient = patient.withUpdatedTimestamp()
    _ = try await repository.upsertPatient(updatedPatient)

    return newOperation
  }
}
