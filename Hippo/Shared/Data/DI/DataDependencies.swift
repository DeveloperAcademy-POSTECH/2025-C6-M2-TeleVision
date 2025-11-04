import Dependencies
import SwiftData
import Foundation

// MARK: - Data Layer Dependencies

extension DependencyValues {
  // MARK: - SwiftData Container

  /// SwiftData ModelContainer for Patient domain
  public var patientModelContainer: ModelContainer {
    get { self[PatientModelContainerKey.self] }
    set { self[PatientModelContainerKey.self] = newValue }
  }

  // MARK: - Local Data Sources

  /// Patient local data source (SwiftData SSOT)
  public var patientLocalDataSource: PatientLocalDataSource {
    get { self[PatientLocalDataSourceKey.self] }
    set { self[PatientLocalDataSourceKey.self] = newValue }
  }

  // MARK: - Remote Data Sources

  /// Patient remote data source (CloudKit)
  public var patientRemoteDataSource: PatientRemoteDataSource {
    get { self[PatientRemoteDataSourceKey.self] }
    set { self[PatientRemoteDataSourceKey.self] = newValue }
  }

  // MARK: - Repositories

  /// Patient repository (offline-first)
  public var patientRepository: PatientRepository {
    get { self[PatientRepositoryKey.self] }
    set { self[PatientRepositoryKey.self] = newValue }
  }

  /// Operation repository (facade for operation-centric operations)
  public var operationRepository: OperationRepository {
    get { self[OperationRepositoryKey.self] }
    set { self[OperationRepositoryKey.self] = newValue }
  }
}

// MARK: - Dependency Keys

private enum PatientModelContainerKey: DependencyKey {
  @MainActor
  static let liveValue: ModelContainer = {
    do {
      let schema = Schema([
        SDPatient.self,
        SDOperation.self,
        SDOperationAsset.self,
        SDOperationRecording.self
      ])

      let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none
      )

      return try ModelContainer(
        for: schema,
        configurations: [modelConfiguration]
      )
    } catch {
      fatalError("Failed to create SwiftData ModelContainer: \(error)")
    }
  }()

  @MainActor
  static let testValue: ModelContainer = {
    do {
      let schema = Schema([
        SDPatient.self,
        SDOperation.self,
        SDOperationAsset.self,
        SDOperationRecording.self
      ])

      let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: true  // In-memory for tests
      )

      return try ModelContainer(
        for: schema,
        configurations: [modelConfiguration]
      )
    } catch {
      fatalError("Failed to create test ModelContainer: \(error)")
    }
  }()
}

private enum PatientLocalDataSourceKey: DependencyKey {
  @MainActor
  static let liveValue: PatientLocalDataSource = {
    @Dependency(\.patientModelContainer) var container
    return PatientLocalDataSourceSwiftData(container: container)
  }()

  @MainActor
  static let testValue: PatientLocalDataSource = {
    @Dependency(\.patientModelContainer) var container
    return PatientLocalDataSourceSwiftData(container: container)
  }()
}

private enum PatientRemoteDataSourceKey: DependencyKey {
  static let liveValue: PatientRemoteDataSource = PatientRemoteDataSourceCloudKit()

  // Mock for testing
  static let testValue: PatientRemoteDataSource = PatientRemoteDataSourceMock()
}

private enum PatientRepositoryKey: DependencyKey {
  static let liveValue: PatientRepository = {
    @Dependency(\.patientLocalDataSource) var localDataSource
    @Dependency(\.patientRemoteDataSource) var remoteDataSource

    return PatientRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource
    )
  }()

  static let testValue: PatientRepository = {
    @Dependency(\.patientLocalDataSource) var localDataSource
    @Dependency(\.patientRemoteDataSource) var remoteDataSource

    return PatientRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource
    )
  }()
}

private enum OperationRepositoryKey: DependencyKey {
  static let liveValue: OperationRepository = {
    @Dependency(\.patientRepository) var patientRepository

    return OperationRepositoryImpl(patientRepository: patientRepository)
  }()

  static let testValue: OperationRepository = {
    @Dependency(\.patientRepository) var patientRepository

    return OperationRepositoryImpl(patientRepository: patientRepository)
  }()
}

// MARK: - Mock Remote Data Source (for testing)

private final class PatientRemoteDataSourceMock: PatientRemoteDataSource {
  func pullAll() async throws -> [Patient] {
    return []
  }

  func push(_ patient: Patient) async throws {
    // Mock: do nothing
  }

  func remove(id: String) async throws {
    // Mock: do nothing
  }
}
