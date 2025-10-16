import Dependencies
import Foundation

public struct DeletePatient: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ id: PatientID) async throws {
        try await repository.deletePatient(id: id)
    }
}

// MARK: - Dependency
extension DeletePatient: DependencyKey {
    public static let liveValue = DeletePatient(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var deletePatient: DeletePatient {
        get { self[DeletePatient.self] }
        set { self[DeletePatient.self] = newValue }
    }
}

// MARK: - Mock Repository
private final class MockPatientRepository: PatientRepository, @unchecked Sendable {
    func listPatients() async throws -> [Patient] { [] }
    func getPatient(id: PatientID) async throws -> Patient {
        Patient(name: "Mock Patient")
    }
    func upsertPatient(_ patient: Patient) async throws -> Patient { patient }
    func deletePatient(id: PatientID) async throws {}
    func upsertCase(patientID: PatientID, case: Case) async throws {}
    func deleteCase(patientID: PatientID, caseID: CaseID) async throws {}
    func attachModelToCase(patientID: PatientID, caseID: CaseID, file: ModelFile) async throws {}
    func removeModelFromCase(patientID: PatientID, caseID: CaseID, modelID: ModelID) async throws {}
}
