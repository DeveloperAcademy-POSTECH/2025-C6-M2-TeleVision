import Dependencies
import Foundation

public struct AttachModelToOperation: Sendable {
    public struct Input: Sendable {
        public let patientID: PatientID
        public let operationID: OperationID
        public let file: OperationAsset

        public init(patientID: PatientID, operationID: OperationID, file: OperationAsset) {
            self.patientID = patientID
            self.operationID = operationID
            self.file = file
        }
    }

    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ input: Input) async throws {
        try await repository.attachModelToOperation(
            patientID: input.patientID,
            operationID: input.operationID,
            file: input.file
        )
    }
}

// MARK: - Dependency
extension AttachModelToOperation: DependencyKey {
    public static let liveValue = AttachModelToOperation(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var attachModelToOperation: AttachModelToOperation {
        get { self[AttachModelToOperation.self] }
        set { self[AttachModelToOperation.self] = newValue }
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
