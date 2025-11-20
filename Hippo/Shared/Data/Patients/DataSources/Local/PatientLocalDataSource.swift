import Foundation

// MARK: - PatientLocalDataSource Protocol

/// Local data source protocol for Patient operations
/// Implemented by both SwiftData (SSOT) and Legacy JSON (read-only import)
public protocol PatientLocalDataSource: Sendable {
  /// List all patients
  func listPatients() throws -> [Patient]

  /// Get a specific patient by ID
  func getPatient(id: String) throws -> Patient?

  /// Insert or update a patient (CRUD in SwiftData, throws in Legacy JSON)
  func upsert(_ patient: Patient) throws

  /// Delete a patient by ID (CRUD in SwiftData, throws in Legacy JSON)
  func deletePatient(id: String) throws
}
