import Dependencies
import Foundation

public struct ListPatients: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run() async throws -> [Patient] {
        try await repository.listPatients()
    }
}

// MARK: - Dependency
extension ListPatients: DependencyKey {
    public static let liveValue = ListPatients(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var listPatients: ListPatients {
        get { self[ListPatients.self] }
        set { self[ListPatients.self] = newValue }
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
    func upsertOperation(patientID: PatientID, operation: Operation) async throws {}
    func deleteOperation(patientID: PatientID, operationID: OperationID) async throws {}
    func attachModelToOperation(patientID: PatientID, operationID: OperationID, file: OperationAsset) async throws {}
    func removeModelFromOperation(patientID: PatientID, operationID: OperationID, assetID: AssetID) async throws {}
}
