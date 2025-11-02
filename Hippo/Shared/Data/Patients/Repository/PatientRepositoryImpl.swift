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

    public func addAssets(
        _ assets: [OperationAsset],
        toOperationID operationID: String,
        inPatientID patientID: String
    ) async throws {
        // 1. 로컬에서 Patient 가져오기
        guard var patient = try await localDataSource.getPatient(id: patientID) else {
            throw PatientError.patientNotFound
        }
        print("1️⃣ Patient found: \(patient.name)")

        // 2. Operation 찾기
        guard let operationIndex = patient.operations.firstIndex(where: { $0.id == operationID }) else {
            throw PatientError.operationNotFound
        }
        print("2️⃣ Operation found: \(patient.operations[operationIndex].title)")

        // 3. assets를 operation에 추가
        patient.operations[operationIndex].operationAssets.append(contentsOf: assets)
        print("3️⃣ Assets added. Total assets now: \(patient.operations[operationIndex].operationAssets.count)")

        // 4. 저장
        try await localDataSource.upsert(patient)
        print("4️⃣ Patient updated in local data source.")

        // 5. 동기화 (옵션)
//        try? await syncPatient(sdPatient)
    }

    public func removeAsset(
        _ assetID: String,
        fromOperationID operationID: String,
        inPatientID patientID: String
    ) async throws {
        // 1. 로컬에서 Patient 가져오기
        guard let patient = try await localDataSource.getPatient(id: patientID) else {
            throw PatientError.patientNotFound
        }

        // 2. Operation 찾기
        guard var operation = patient.operations.first(where: { $0.id == operationID }) else {
            throw PatientError.operationNotFound
        }

        // 3. Asset 찾기 및 파일 삭제
        if operation.operationAssets.first(where: { $0.id == assetID }) != nil {
            operation.operationAssets.removeAll { $0.id == assetID }
        }

        // 4. 저장
        try await localDataSource.upsert(patient)

        // 5. 동기화 (옵션)
//        try? await syncPatient(sdPatient)
    }

    public func getAssets(
        forOperationID operationID: String,
        inPatientID patientID: String
    ) async throws -> [OperationAsset] {
        // 1. 로컬에서 Patient 가져오기
        guard let sdPatient = try await localDataSource.getPatient(id: patientID) else {
            throw PatientError.patientNotFound
        }

        // 2. Operation 찾기
        guard let operation = sdPatient.operations.first(where: { $0.id == operationID }) else {
            throw PatientError.operationNotFound
        }

        // 3. OperationAsset 반환
        return operation.operationAssets
    }

    private func syncPatient(_: SDPatient) async throws {
        // CloudKit 동기화 로직 (나중에 구현)
    }
}

// MARK: - Error Types

public enum PatientError: Error {
    case patientNotFound
    case operationNotFound
    case assetNotFound
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
        case let .syncFailed(error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}
