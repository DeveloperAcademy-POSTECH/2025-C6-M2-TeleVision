import Foundation

/// Use Case for creating a new patient
public struct CreatePatient: Sendable {
  public struct Input: Sendable {
    public let command: CreatePatientCommand

    public init(command: CreatePatientCommand) {
      self.command = command
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  /// Creates a new patient
  /// - Parameter input: Input containing patient command
  /// - Throws: Repository errors or validation errors
  /// - Returns: The created Patient entity
  @discardableResult
  public func run(_ input: Input) async throws -> Patient {
    // Convert command to patient entity (UUID and timestamps generated here)
    let newPatient = input.command.toPatient()

    // Save to repository
    _ = try await repository.upsertPatient(newPatient)

    return newPatient
  }
}
