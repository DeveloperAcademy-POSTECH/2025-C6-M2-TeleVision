import Dependencies
import Foundation

// MARK: - Domain Layer Dependencies (Use Cases)

public extension DependencyValues {
    // MARK: - Patient Use Cases

    var listPatients: ListPatients {
        get { self[ListPatients.self] }
        set { self[ListPatients.self] = newValue }
    }

    var getPatient: GetPatient {
        get { self[GetPatient.self] }
        set { self[GetPatient.self] = newValue }
    }

    var createPatient: CreatePatient {
        get { self[CreatePatient.self] }
        set { self[CreatePatient.self] = newValue }
    }

    var updatePatient: UpdatePatient {
        get { self[UpdatePatient.self] }
        set { self[UpdatePatient.self] = newValue }
    }

    var deletePatient: DeletePatient {
        get { self[DeletePatient.self] }
        set { self[DeletePatient.self] = newValue }
    }

    // MARK: - Operation Use Cases

    var createOperation: CreateOperation {
        get { self[CreateOperation.self] }
        set { self[CreateOperation.self] = newValue }
    }

    var upsertOperation: UpsertOperation {
        get { self[UpsertOperation.self] }
        set { self[UpsertOperation.self] = newValue }
    }

    var deleteOperation: DeleteOperation {
        get { self[DeleteOperation.self] }
        set { self[DeleteOperation.self] = newValue }
    }

    var getOperation: GetOperation {
        get { self[GetOperation.self] }
        set { self[GetOperation.self] = newValue }
    }

    var getTodayOperations: GetTodayOperations {
        get { self[GetTodayOperations.self] }
        set { self[GetTodayOperations.self] = newValue }
    }

    var updateOperationStatus: UpdateOperationStatus {
        get { self[UpdateOperationStatus.self] }
        set { self[UpdateOperationStatus.self] = newValue }
    }

    // MARK: - Asset Use Cases

    var attachAssetToOperation: AttachAssetToOperation {
        get { self[AttachAssetToOperation.self] }
        set { self[AttachAssetToOperation.self] = newValue }
    }

    var removeAssetFromOperation: RemoveAssetFromOperation {
        get { self[RemoveAssetFromOperation.self] }
        set { self[RemoveAssetFromOperation.self] = newValue }
    }

    // MARK: - Recording Use Cases

    var addRecordingToOperation: AddRecordingToOperation {
        get { self[AddRecordingToOperation.self] }
        set { self[AddRecordingToOperation.self] = newValue }
    }
}

// MARK: - Use Case Dependency Keys

extension ListPatients: DependencyKey {
    public static var liveValue: ListPatients {
        @Dependency(\.patientRepository) var repository
        return ListPatients(repository: repository)
    }

    public static var testValue: ListPatients {
        @Dependency(\.patientRepository) var repository
        return ListPatients(repository: repository)
    }
}

extension GetPatient: DependencyKey {
    public static var liveValue: GetPatient {
        @Dependency(\.patientRepository) var repository
        return GetPatient(repository: repository)
    }

    public static var testValue: GetPatient {
        @Dependency(\.patientRepository) var repository
        return GetPatient(repository: repository)
    }
}

extension DeletePatient: DependencyKey {
    public static var liveValue: DeletePatient {
        @Dependency(\.patientRepository) var repository
        return DeletePatient(repository: repository)
    }

    public static var testValue: DeletePatient {
        @Dependency(\.patientRepository) var repository
        return DeletePatient(repository: repository)
    }
}

extension CreatePatient: DependencyKey {
    public static var liveValue: CreatePatient {
        @Dependency(\.patientRepository) var repository
        return CreatePatient(repository: repository)
    }

    public static var testValue: CreatePatient {
        @Dependency(\.patientRepository) var repository
        return CreatePatient(repository: repository)
    }
}

extension UpdatePatient: DependencyKey {
    public static var liveValue: UpdatePatient {
        @Dependency(\.patientRepository) var repository
        return UpdatePatient(repository: repository)
    }

    public static var testValue: UpdatePatient {
        @Dependency(\.patientRepository) var repository
        return UpdatePatient(repository: repository)
    }
}

extension CreateOperation: DependencyKey {
    public static var liveValue: CreateOperation {
        @Dependency(\.operationRepository) var repository
        return CreateOperation(repository: repository)
    }

    public static var testValue: CreateOperation {
        @Dependency(\.operationRepository) var repository
        return CreateOperation(repository: repository)
    }
}

extension UpsertOperation: DependencyKey {
    public static var liveValue: UpsertOperation {
        @Dependency(\.operationRepository) var repository
        return UpsertOperation(repository: repository)
    }

    public static var testValue: UpsertOperation {
        @Dependency(\.operationRepository) var repository
        return UpsertOperation(repository: repository)
    }
}

extension DeleteOperation: DependencyKey {
    public static var liveValue: DeleteOperation {
        @Dependency(\.operationRepository) var repository
        return DeleteOperation(repository: repository)
    }

    public static var testValue: DeleteOperation {
        @Dependency(\.operationRepository) var repository
        return DeleteOperation(repository: repository)
    }
}

extension GetOperation: DependencyKey {
    public static var liveValue: GetOperation {
        @Dependency(\.operationRepository) var repository
        return GetOperation(repository: repository)
    }

    public static var testValue: GetOperation {
        @Dependency(\.operationRepository) var repository
        return GetOperation(repository: repository)
    }
}

extension GetTodayOperations: DependencyKey {
    public static var liveValue: GetTodayOperations {
        @Dependency(\.operationRepository) var repository
        return GetTodayOperations(repository: repository)
    }

    public static var testValue: GetTodayOperations {
        @Dependency(\.operationRepository) var repository
        return GetTodayOperations(repository: repository)
    }
}

extension UpdateOperationStatus: DependencyKey {
    public static var liveValue: UpdateOperationStatus {
        @Dependency(\.operationRepository) var repository
        return UpdateOperationStatus(repository: repository)
    }

    public static var testValue: UpdateOperationStatus {
        @Dependency(\.operationRepository) var repository
        return UpdateOperationStatus(repository: repository)
    }
}

extension AttachAssetToOperation: DependencyKey {
    public static var liveValue: AttachAssetToOperation {
        @Dependency(\.operationRepository) var repository
        return AttachAssetToOperation(repository: repository)
    }

    public static var testValue: AttachAssetToOperation {
        @Dependency(\.operationRepository) var repository
        return AttachAssetToOperation(repository: repository)
    }
}

extension RemoveAssetFromOperation: DependencyKey {
    public static var liveValue: RemoveAssetFromOperation {
        @Dependency(\.operationRepository) var repository
        return RemoveAssetFromOperation(repository: repository)
    }

    public static var testValue: RemoveAssetFromOperation {
        @Dependency(\.operationRepository) var repository
        return RemoveAssetFromOperation(repository: repository)
    }
}

extension AddRecordingToOperation: DependencyKey {
    public static var liveValue: AddRecordingToOperation {
        @Dependency(\.operationRepository) var repository
        return AddRecordingToOperation(repository: repository)
    }

    public static var testValue: AddRecordingToOperation {
        @Dependency(\.operationRepository) var repository
        return AddRecordingToOperation(repository: repository)
    }
}
