import Foundation

/// Repository implementation with offline-first strategy
/// Fetches from local immediately, then syncs with remote in background
public actor PatientRepositoryImpl: PatientRepository {
    private let localDataSource: PatientLocalDataSource
    private let remoteDataSource: PatientRemoteDataSource

    // Designated initializer: accepts already-constructed dependencies.
    // This init is not main-actor isolated, so it can be called from anywhere safely.
    public init(
        localDataSource: PatientLocalDataSource,
        remoteDataSource: PatientRemoteDataSource
    ) {
        self.localDataSource = localDataSource
        self.remoteDataSource = remoteDataSource
    }

    // Default initializer that constructs default dependencies.
    // Not marked as convenience because actors don't support convenience initializers.
    public init() {
        let local = PatientLocalDataSourceJSON()
        let remote = PatientRemoteDataSourceCloudKit()
        self.localDataSource = local
        self.remoteDataSource = remote
    }

    // MARK: - Patient Operations

    public func listPatients() async throws -> [Patient] {
        // Offline-first: return local data immediately
        let localPatients = try await localDataSource.fetchAll()

        // Background sync with remote
        Task.detached { [weak self] in
            await self?.syncFromRemote()
        }

        return localPatients.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func getPatient(id: PatientID) async throws -> Patient {
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

        // Background sync to remote
        Task.detached { [weak self, updatedPatient] in
            try? await self?.remoteDataSource.push(updatedPatient)
        }

        return updatedPatient
    }

    public func deletePatient(id: PatientID) async throws {
        var patients = try await localDataSource.fetchAll()
        patients.removeAll { $0.id == id }
        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, id] in
            try? await self?.remoteDataSource.remove(id: id)
        }
    }

    // MARK: - operation Operations

    public func upsertOperation(patientID: PatientID, operation: Operation) async throws {
        var patients = try await localDataSource.fetchAll()
        guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
            throw RepositoryError.notFound
        }

        var patient = patients[patientIndex]
        var updatedOperation = operation
        updatedOperation.updatedAt = Date()

        if let operationIndex = patient.operations.firstIndex(where: { $0.id == operation.id }) {
            patient.operations[operationIndex] = updatedOperation
        } else {
            patient.operations.append(updatedOperation)
        }

        patient.updatedAt = Date()
        patients[patientIndex] = patient

        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, patient] in
            try? await self?.remoteDataSource.push(patient)
        }
    }

    public func deleteOperation(patientID: PatientID, operationID: OperationID) async throws {
        var patients = try await localDataSource.fetchAll()
        guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
            throw RepositoryError.notFound
        }

        var patient = patients[patientIndex]
        patient.operations.removeAll { $0.id == operationID }
        patient.updatedAt = Date()
        patients[patientIndex] = patient

        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, patient] in
            try? await self?.remoteDataSource.push(patient)
        }
    }

    // MARK: - Model Operations

    public func attachModelToOperation(patientID: PatientID, operationID: OperationID, file: OperationAsset) async throws {
        var patients = try await localDataSource.fetchAll()
        guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
            throw RepositoryError.notFound
        }

        var patient = patients[patientIndex]
        guard let operationIndex = patient.operations.firstIndex(where: { $0.id == operationID }) else {
            throw RepositoryError.notFound
        }

        var operation = patient.operations[operationIndex]
        operation.operationAssets.append(file)
        operation.updatedAt = Date()
        patient.operations[operationIndex] = operation
        patient.updatedAt = Date()
        patients[patientIndex] = patient

        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, patient] in
            try? await self?.remoteDataSource.push(patient)
        }
    }

    public func removeModelFromOperation(patientID: PatientID, operationID: OperationID, assetID: AssetID) async throws {
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
        operation.updatedAt = Date()
        patient.operations[operationIndex] = operation
        patient.updatedAt = Date()
        patients[patientIndex] = patient

        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, patient] in
            try? await self?.remoteDataSource.push(patient)
        }
    }

    // MARK: - Private Helpers

    private func syncFromRemote() async {
        // TODO: Implement proper sync logic with conflict resolution
        // For now, just fetch from remote and merge with local
        do {
            let remotePatients = try await remoteDataSource.pullAll()
            var localPatients = try await localDataSource.fetchAll()

            // Simple merge: remote wins if updatedAt is newer
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
            // Silent fail for background sync
            print("Background sync failed: \(error)")
        }
    }
}

// MARK: - Errors
public enum RepositoryError: Error {
    case notFound
    case syncFailed
}
