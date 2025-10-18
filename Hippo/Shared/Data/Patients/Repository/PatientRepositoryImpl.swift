import Foundation

/// Repository implementation with offline-first strategy
/// Fetches from local immediately, then syncs with remote in background
public actor PatientRepositoryImpl: PatientRepository {
  private let localDataSource: PatientLocalDataSource
  private let remoteDataSource: PatientRemoteDataSource

  public init(
    localDataSource: PatientLocalDataSource,
    remoteDataSource: PatientRemoteDataSource
  ) {
    self.localDataSource = localDataSource
    self.remoteDataSource = remoteDataSource
  }

  public init() {
    let local = PatientLocalDataSourceJSON()
    let remote = PatientRemoteDataSourceCloudKit()
    self.localDataSource = local
    self.remoteDataSource = remote
  }

  // MARK: - Patient Operations

  public func listPatients() async throws -> [Patient] {
    let localPatients = try await localDataSource.fetchAll()

    Task.detached { [weak self] in
      await self?.syncFromRemote()
    }

    return localPatients.sorted { $0.updatedAt > $1.updatedAt }
  }

  public func getPatient(id: String) async throws -> Patient {
    let patients = try await localDataSource.fetchAll()
    guard let patient = patients.first(where: { $0.id == id }) else {
      throw RepositoryError.notFound
    }
    return patient
  }

  public func upsertPatient(_ patient: Patient) async throws -> Patient {
    var patients = try await localDataSource.fetchAll()
    var updatedPatient = patient
    updatedPatient.updatedAt = Date()

    if let index = patients.firstIndex(where: { $0.id == patient.id }) {
      patients[index] = updatedPatient
    } else {
      patients.append(updatedPatient)
    }

    try await localDataSource.saveAll(patients)

    Task.detached { [weak self, updatedPatient] in
      try? await self?.remoteDataSource.push(updatedPatient)
    }

    return updatedPatient
  }

  public func deletePatient(id: String) async throws {
    var patients = try await localDataSource.fetchAll()
    patients.removeAll { $0.id == id }
    try await localDataSource.saveAll(patients)

    Task.detached { [weak self, id] in
      try? await self?.remoteDataSource.remove(id: id)
    }
  }

  // MARK: - Operation Operations

  public func upsertOperation(patientID: String, operation: Operation) async throws {
    var patients = try await localDataSource.fetchAll()
    guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
      throw RepositoryError.notFound
    }

    var patient = patients[patientIndex]

    if let operationIndex = patient.operations.firstIndex(where: { $0.id == operation.id }) {
      patient.operations[operationIndex] = operation
    } else {
      patient.operations.append(operation)
    }

    patient.updatedAt = Date()
    patients[patientIndex] = patient

    try await localDataSource.saveAll(patients)

    Task.detached { [weak self, patient] in
      try? await self?.remoteDataSource.push(patient)
    }
  }

  public func deleteOperation(patientID: String, operationID: String) async throws {
    var patients = try await localDataSource.fetchAll()
    guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
      throw RepositoryError.notFound
    }

    var patient = patients[patientIndex]
    patient.operations.removeAll { $0.id == operationID }
    patient.updatedAt = Date()
    patients[patientIndex] = patient

    try await localDataSource.saveAll(patients)

    Task.detached { [weak self, patient] in
      try? await self?.remoteDataSource.push(patient)
    }
  }

  // MARK: - OperationAsset Operations

  public func attachAssetToOperation(patientID: String, operationID: String, asset: OperationAsset) async throws {
    var patients = try await localDataSource.fetchAll()
    guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
      throw RepositoryError.notFound
    }

    var patient = patients[patientIndex]
    guard let operationIndex = patient.operations.firstIndex(where: { $0.id == operationID }) else {
      throw RepositoryError.notFound
    }

    var operation = patient.operations[operationIndex]
    operation.operationAssets.append(asset)
    patient.operations[operationIndex] = operation
    patient.updatedAt = Date()
    patients[patientIndex] = patient

    try await localDataSource.saveAll(patients)

    Task.detached { [weak self, patient] in
      try? await self?.remoteDataSource.push(patient)
    }
  }

  public func removeAssetFromOperation(patientID: String, operationID: String, assetID: String) async throws {
    var patients = try await localDataSource.fetchAll()
    guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
      throw RepositoryError.notFound
    }

    var patient = patients[patientIndex]
    guard let operationIndex = patient.operations.firstIndex(where: { $0.id == operationID }) else {
      throw RepositoryError.notFound
    }

    var operation = patient.operations[operationIndex]
    operation.operationAssets.removeAll { $0.id == assetID }
    patient.operations[operationIndex] = operation
    patient.updatedAt = Date()
    patients[patientIndex] = patient

    try await localDataSource.saveAll(patients)

    Task.detached { [weak self, patient] in
      try? await self?.remoteDataSource.push(patient)
    }
  }

  // MARK: - Private Helpers

  private func syncFromRemote() async {
    do {
      let remotePatients = try await remoteDataSource.pullAll()
      var localPatients = try await localDataSource.fetchAll()

      for remotePatient in remotePatients {
        if let localIndex = localPatients.firstIndex(where: { $0.id == remotePatient.id }) {
          if remotePatient.updatedAt > localPatients[localIndex].updatedAt {
            localPatients[localIndex] = remotePatient
          }
        } else {
          localPatients.append(remotePatient)
        }
      }

      try await localDataSource.saveAll(localPatients)
    } catch {
      print("Background sync failed: \(error)")
    }
  }
}

// MARK: - Errors
public enum RepositoryError: Error {
  case notFound
  case syncFailed
}
