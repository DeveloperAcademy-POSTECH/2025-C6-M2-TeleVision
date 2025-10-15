import Foundation

/// Repository interface for Patient domain operations
public protocol PatientRepository: Sendable {
    // Patient operations
    func listPatients() async throws -> [Patient]
    func getPatient(id: PatientID) async throws -> Patient
    func upsertPatient(_ patient: Patient) async throws -> Patient
    func deletePatient(id: PatientID) async throws

    // Case operations
    func upsertCase(patientID: PatientID, case: Case) async throws
    func deleteCase(patientID: PatientID, caseID: CaseID) async throws

    // Model operations
    func attachModelToCase(patientID: PatientID, caseID: CaseID, file: ModelFile) async throws
    func removeModelFromCase(patientID: PatientID, caseID: CaseID, modelID: ModelID) async throws
}
