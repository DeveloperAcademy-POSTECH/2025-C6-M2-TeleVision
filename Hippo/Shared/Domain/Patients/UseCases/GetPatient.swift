import Dependencies
import Foundation

public struct GetPatient: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ id: PatientID) async throws -> Patient {
        try await repository.getPatient(id: id)
    }
}

// MARK: - Dependency
extension GetPatient: DependencyKey {
    public static let liveValue = GetPatient(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var getPatient: GetPatient {
        get { self[GetPatient.self] }
        set { self[GetPatient.self] = newValue }
    }
}

// MARK: - Mock Repository
private final class MockPatientRepository: PatientRepository, @unchecked Sendable {
    func listPatients() async throws -> [Patient] { [] }
    func getPatient(id: PatientID) async throws -> Patient {
        Patient(id: id, name: "Mock Patient")
    }
    func upsertPatient(_ patient: Patient) async throws -> Patient { patient }
    func deletePatient(id: PatientID) async throws {}
    // Operation operations
    func upsertOperation(patientID: PatientID, operation: Operation) async throws {}
    func deleteOperation(patientID: PatientID, operationID: OperationID) async throws {}
    func attachModelToOperation(patientID: PatientID, operationID: OperationID, file: OperationAsset) async throws {}
    func removeModelFromOperation(patientID: PatientID, operationID: OperationID, assetID: AssetID) async throws {}
}
