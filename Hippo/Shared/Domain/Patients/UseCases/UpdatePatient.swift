import Foundation

/// Use Case for updating an existing patient
public struct UpdatePatient: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let command: UpdatePatientCommand

    public init(patientID: String, command: UpdatePatientCommand) {
      self.patientID = patientID
      self.command = command
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  /// Updates an existing patient
  /// - Parameter input: Input containing patient ID and update command
  /// - Throws: Repository errors or patient not found error
  /// - Returns: The updated Patient entity
  @discardableResult
  public func run(_ input: Input) async throws -> Patient {
    // Get existing patient
    var patient = try await repository.getPatient(id: input.patientID)

    // Apply updates from command
    patient.patientNumber = input.command.patientNumber
    patient.name = input.command.name
    patient.gender = input.command.gender
    patient.birthDate = input.command.birthDate

    // Update timestamp and save
    let updatedPatient = patient.withUpdatedTimestamp()
    return try await repository.upsertPatient(updatedPatient)
  }
}
