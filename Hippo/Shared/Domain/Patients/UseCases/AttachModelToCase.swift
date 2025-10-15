import Dependencies
import Foundation

public struct AttachModelToCase: Sendable {
    public struct Input: Sendable {
        public let patientID: PatientID
        public let caseID: CaseID
        public let file: ModelFile

        public init(patientID: PatientID, caseID: CaseID, file: ModelFile) {
            self.patientID = patientID
            self.caseID = caseID
            self.file = file
        }
    }

    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ input: Input) async throws {
        try await repository.attachModelToCase(
            patientID: input.patientID,
            caseID: input.caseID,
            file: input.file
        )
    }
}

// MARK: - Dependency
extension AttachModelToCase: DependencyKey {
    public static let liveValue = AttachModelToCase(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var attachModelToCase: AttachModelToCase {
        get { self[AttachModelToCase.self] }
        set { self[AttachModelToCase.self] = newValue }
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
