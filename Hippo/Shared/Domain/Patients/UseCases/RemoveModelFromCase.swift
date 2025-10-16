import Dependencies
import Foundation

public struct RemoveModelFromCase: Sendable {
    public struct Input: Sendable {
        public let patientID: PatientID
        public let caseID: CaseID
        public let modelID: ModelID

        public init(patientID: PatientID, caseID: CaseID, modelID: ModelID) {
            self.patientID = patientID
            self.caseID = caseID
            self.modelID = modelID
        }
    }

    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ input: Input) async throws {
        try await repository.removeModelFromCase(
            patientID: input.patientID,
            caseID: input.caseID,
            modelID: input.modelID
        )
    }
}

// MARK: - Dependency
extension RemoveModelFromCase: DependencyKey {
    public static let liveValue = RemoveModelFromCase(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var removeModelFromCase: RemoveModelFromCase {
        get { self[RemoveModelFromCase.self] }
        set { self[RemoveModelFromCase.self] = newValue }
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
