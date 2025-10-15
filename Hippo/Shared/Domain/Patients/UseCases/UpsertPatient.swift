import Dependencies
import Foundation

public struct UpsertPatient: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ patient: Patient) async throws -> Patient {
        try await repository.upsertPatient(patient)
    }
}

// MARK: - Dependency
extension UpsertPatient: DependencyKey {
    public static let liveValue = UpsertPatient(
        repository: PatientRepositoryImpl()
    )

    public static let testValue = UpsertPatient(
        repository: MockPatientRepository()
    )
}

extension DependencyValues {
    public var upsertPatient: UpsertPatient {
        get { self[UpsertPatient.self] }
        set { self[UpsertPatient.self] = newValue }
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
