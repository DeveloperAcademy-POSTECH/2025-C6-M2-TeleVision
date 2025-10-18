import Foundation

// MARK: - PatientRepositoryImpl

/// Repository implementation with offline-first strategy
/// - Local operations execute immediately on MainActor
/// - Remote sync happens asynchronously in background
/// - Follows actor isolation for thread-safe data access
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

  // MARK: - Patient Operations

  public func listPatients() async throws -> [Patient] {
    let patients = try await fetchFromLocal { dataSource in
      try dataSource.listPatients()
    }

    backgroundSync()

    return patients.sorted { $0.updatedAt > $1.updatedAt }
  }

  public func getPatient(id: String) async throws -> Patient {
    let patient = try await fetchFromLocal { dataSource in
      try dataSource.getPatient(id: id)
    }

    guard let patient else {
      throw RepositoryError.notFound
    }

    return patient
  }

  public func upsertPatient(_ patient: Patient) async throws -> Patient {
    try await saveToLocal {
      try $0.upsert(patient)
    }

    backgroundPush(patient)

    return patient
  }

  public func deletePatient(id: String) async throws {
    try await saveToLocal {
      try $0.deletePatient(id: id)
    }

    backgroundRemove(id: id)
  }

}

// MARK: - Private Helpers (Data Source Access)

private extension PatientRepositoryImpl {
  /// Fetch data from local data source on MainActor
  func fetchFromLocal<T>(
    _ operation: @MainActor @escaping (PatientLocalDataSource) throws -> T
  ) async throws -> T {
    try await MainActor.run {
      try operation(localDataSource)
    }
  }

  /// Save data to local data source on MainActor
  func saveToLocal(
    _ operation: @MainActor @escaping (PatientLocalDataSource) throws -> Void
  ) async throws {
    try await MainActor.run {
      try operation(localDataSource)
    }
  }
}

// MARK: - Private Helpers (Background Sync)

private extension PatientRepositoryImpl {
  /// Background sync from remote (fire-and-forget)
  func backgroundSync() {
    Task.detached { [weak self] in
      await self?.syncFromRemote()
    }
  }

  /// Background push to remote (fire-and-forget)
  func backgroundPush(_ patient: Patient) {
    Task.detached { [weak self] in
      try? await self?.remoteDataSource.push(patient)
    }
  }

  /// Background remove from remote (fire-and-forget)
  func backgroundRemove(id: String) {
    Task.detached { [weak self] in
      try? await self?.remoteDataSource.remove(id: id)
    }
  }

  /// Sync all patients from remote to local
  /// Merges remote changes with local data based on updatedAt timestamp
  func syncFromRemote() async {
    do {
      let remotePatients = try await remoteDataSource.pullAll()

      try await MainActor.run {
        let localPatients = try localDataSource.listPatients()

        for remotePatient in remotePatients {
          let shouldUpdate = localPatients
            .first(where: { $0.id == remotePatient.id })
            .map { remotePatient.updatedAt > $0.updatedAt } ?? true

          if shouldUpdate {
            try localDataSource.upsert(remotePatient)
          }
        }
      }
    } catch {
      // TODO: Implement proper error handling/retry mechanism
      print("⚠️ Background sync failed: \(error.localizedDescription)")
    }
  }
}

// MARK: - Errors

public enum RepositoryError: Error, LocalizedError {
  case notFound
  case syncFailed(Error)

  public var errorDescription: String? {
    switch self {
    case .notFound:
      return "Patient not found"
    case .syncFailed(let error):
      return "Sync failed: \(error.localizedDescription)"
    }
  }
}
