import Dependencies
import Foundation

// MARK: - Domain Layer Dependencies (Use Cases)

extension DependencyValues {
  // MARK: - Patient Use Cases

  public var listPatients: ListPatients {
    get { self[ListPatients.self] }
    set { self[ListPatients.self] = newValue }
  }

  public var getPatient: GetPatient {
    get { self[GetPatient.self] }
    set { self[GetPatient.self] = newValue }
  }

  public var createPatient: CreatePatient {
    get { self[CreatePatient.self] }
    set { self[CreatePatient.self] = newValue }
  }

  public var updatePatient: UpdatePatient {
    get { self[UpdatePatient.self] }
    set { self[UpdatePatient.self] = newValue }
  }

  public var deletePatient: DeletePatient {
    get { self[DeletePatient.self] }
    set { self[DeletePatient.self] = newValue }
  }

  // MARK: - Operation Use Cases

  public var createOperation: CreateOperation {
    get { self[CreateOperation.self] }
    set { self[CreateOperation.self] = newValue }
  }

  public var upsertOperation: UpsertOperation {
    get { self[UpsertOperation.self] }
    set { self[UpsertOperation.self] = newValue }
  }

  public var deleteOperation: DeleteOperation {
    get { self[DeleteOperation.self] }
    set { self[DeleteOperation.self] = newValue }
  }

  // MARK: - Asset Use Cases

  public var attachAssetToOperation: AttachAssetToOperation {
    get { self[AttachAssetToOperation.self] }
    set { self[AttachAssetToOperation.self] = newValue }
  }

  public var removeAssetFromOperation: RemoveAssetFromOperation {
    get { self[RemoveAssetFromOperation.self] }
    set { self[RemoveAssetFromOperation.self] = newValue }
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
    @Dependency(\.patientRepository) var repository
    return CreateOperation(repository: repository)
  }

  public static var testValue: CreateOperation {
    @Dependency(\.patientRepository) var repository
    return CreateOperation(repository: repository)
  }
}

extension UpsertOperation: DependencyKey {
  public static var liveValue: UpsertOperation {
    @Dependency(\.patientRepository) var repository
    return UpsertOperation(repository: repository)
  }

  public static var testValue: UpsertOperation {
    @Dependency(\.patientRepository) var repository
    return UpsertOperation(repository: repository)
  }
}

extension DeleteOperation: DependencyKey {
  public static var liveValue: DeleteOperation {
    @Dependency(\.patientRepository) var repository
    return DeleteOperation(repository: repository)
  }

  public static var testValue: DeleteOperation {
    @Dependency(\.patientRepository) var repository
    return DeleteOperation(repository: repository)
  }
}

extension AttachAssetToOperation: DependencyKey {
  public static var liveValue: AttachAssetToOperation {
    @Dependency(\.patientRepository) var repository
    return AttachAssetToOperation(repository: repository)
  }

  public static var testValue: AttachAssetToOperation {
    @Dependency(\.patientRepository) var repository
    return AttachAssetToOperation(repository: repository)
  }
}

extension RemoveAssetFromOperation: DependencyKey {
  public static var liveValue: RemoveAssetFromOperation {
    @Dependency(\.patientRepository) var repository
    return RemoveAssetFromOperation(repository: repository)
  }

  public static var testValue: RemoveAssetFromOperation {
    @Dependency(\.patientRepository) var repository
    return RemoveAssetFromOperation(repository: repository)
  }
}
