import Foundation

/// Command object for updating an existing patient
/// Encapsulates all required parameters with validation
public struct UpdatePatientCommand: Sendable {
  public let patientNumber: String
  public let name: String
  public let gender: Gender
  public let birthDate: Date

  /// Creates a new update patient command with validation
  /// - Parameters:
  ///   - patientNumber: Unique patient identifier (must not be empty)
  ///   - name: Patient name (must not be empty)
  ///   - gender: Patient gender
  ///   - birthDate: Patient birth date
  /// - Throws: `ValidationError` if any required field is invalid
  public init(
    patientNumber: String,
    name: String,
    gender: Gender,
    birthDate: Date
  ) throws {
    // Validation
    guard !patientNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw ValidationError.emptyField("patientNumber")
    }

    guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
      throw ValidationError.emptyField("name")
    }

    // Birth date should not be in the future
    guard birthDate <= Date() else {
      throw ValidationError.invalidField("birthDate", "Birth date cannot be in the future")
    }

    self.patientNumber = patientNumber.trimmingCharacters(in: .whitespaces)
    self.name = name.trimmingCharacters(in: .whitespaces)
    self.gender = gender
    self.birthDate = birthDate
  }
}
