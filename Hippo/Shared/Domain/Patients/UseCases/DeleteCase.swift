import Dependencies
import Foundation

public struct DeleteOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: PatientID
        public let operationID: OperationID

        public init(patientID: PatientID, operationID: OperationID) {
            self.patientID = patientID
            self.operationID = operationID
        }
    }

    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ input: Input) async throws {
        try await repository.deleteOperation(patientID: input.patientID, operationID: input.operationID)
    }
}

// MARK: - Dependency
extension DeleteOperation: DependencyKey {
    public static let liveValue = DeleteOperation(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var deleteOperation: DeleteOperation {
        get { self[DeleteOperation.self] }
        set { self[DeleteOperation.self] = newValue }
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
    // Operation methods
    func upsertOperation(patientID: PatientID, operation: Operation) async throws {}
    func deleteOperation(patientID: PatientID, operationID: OperationID) async throws {}
    func attachModelToOperation(patientID: PatientID, operationID: OperationID, file: OperationAsset) async throws {}
    func removeModelFromOperation(patientID: PatientID, operationID: OperationID, assetID: AssetID) async throws {}
}
