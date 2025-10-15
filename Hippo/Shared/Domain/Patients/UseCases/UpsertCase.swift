import Dependencies
import Foundation

public struct UpsertCase: Sendable {
    public struct Input: Sendable {
        public let patientID: PatientID
        public let `case`: Case

        public init(patientID: PatientID, case: Case) {
            self.patientID = patientID
            self.case = `case`
        }
    }

    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ input: Input) async throws {
        try await repository.upsertCase(patientID: input.patientID, case: input.case)
    }
}

// MARK: - Dependency
extension UpsertCase: DependencyKey {
    public static let liveValue = UpsertCase(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var upsertCase: UpsertCase {
        get { self[UpsertCase.self] }
        set { self[UpsertCase.self] = newValue }
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
