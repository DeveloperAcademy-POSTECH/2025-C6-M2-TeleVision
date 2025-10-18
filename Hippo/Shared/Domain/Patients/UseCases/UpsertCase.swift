import Dependencies
import Foundation

public struct UpsertOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: PatientID
        public let operation: Operation

        public init(patientID: PatientID, operation: Operation) {
            self.patientID = patientID
            self.operation = operation
        }
    }

    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ input: Input) async throws {
        try await repository.upsertOperation(patientID: input.patientID, operation: input.operation)
    }
}

// MARK: - Dependency
extension UpsertOperation: DependencyKey {
    public static let liveValue = UpsertOperation(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var upsertOperation: UpsertOperation {
        get { self[UpsertOperation.self] }
        set { self[UpsertOperation.self] = newValue }
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
