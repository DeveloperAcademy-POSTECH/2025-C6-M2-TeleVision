import Dependencies
import Foundation

public struct RemoveModelFromOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: PatientID
        public let operationID: OperationID
        public let assetID: AssetID

        public init(patientID: PatientID, operationID: OperationID, assetID: AssetID) {
            self.patientID = patientID
            self.operationID = operationID
            self.assetID = assetID
        }
    }

    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ input: Input) async throws {
        try await repository.removeModelFromOperation(
            patientID: input.patientID,
            operationID: input.operationID,
            assetID: input.assetID
        )
    }
}

// MARK: - Dependency
extension RemoveModelFromOperation: DependencyKey {
    public static let liveValue = RemoveModelFromOperation(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var removeModelFromOperation: RemoveModelFromOperation {
        get { self[RemoveModelFromOperation.self] }
        set { self[RemoveModelFromOperation.self] = newValue }
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
