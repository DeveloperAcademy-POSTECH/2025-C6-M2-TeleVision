import Foundation

/// Repository interface for Patient domain operations
/// Repository is responsible for data persistence only.
/// Business logic (like timestamp updates) should be handled in Use Cases.
public protocol PatientRepository: Sendable {
  /// List all patients sorted by last update
  func listPatients() async throws -> [Patient]

  /// Get a specific patient by ID
  func getPatient(id: String) async throws -> Patient

  /// Insert or update a patient
  /// - Note: Caller is responsible for updating timestamps
  func upsertPatient(_ patient: Patient) async throws -> Patient

  /// Delete a patient by ID
  func deletePatient(id: String) async throws
}
