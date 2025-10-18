import Foundation

/// Repository interface for Patient domain operations
public protocol PatientRepository: Sendable {
  // Patient operations
  func listPatients() async throws -> [Patient]
  func getPatient(id: String) async throws -> Patient
  func upsertPatient(_ patient: Patient) async throws -> Patient
  func deletePatient(id: String) async throws

  // Operation operations
  func upsertOperation(patientID: String, operation: Operation) async throws
  func deleteOperation(patientID: String, operationID: String) async throws

  // OperationAsset operations
  func attachAssetToOperation(patientID: String, operationID: String, asset: OperationAsset) async throws
  func removeAssetFromOperation(patientID: String, operationID: String, assetID: String) async throws
}
