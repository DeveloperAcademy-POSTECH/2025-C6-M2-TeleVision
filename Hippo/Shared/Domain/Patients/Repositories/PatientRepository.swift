import Foundation

/// Repository interface for Patient domain operations
public protocol PatientRepository: Sendable {
    // Patient operations
    func listPatients() async throws -> [Patient]
    func getPatient(id: PatientID) async throws -> Patient
    func upsertPatient(_ patient: Patient) async throws -> Patient
    func deletePatient(id: PatientID) async throws

    // Operation operations
    func upsertOperation(patientID: PatientID, operation: Operation) async throws
    func deleteOperation(patientID: PatientID, operationID: OperationID) async throws

    // Model operations
    func attachModelToOperation(patientID: PatientID, operationID: OperationID, file: OperationAsset) async throws
    func removeModelFromOperation(patientID: PatientID, operationID: OperationID, assetID: AssetID) async throws
}
