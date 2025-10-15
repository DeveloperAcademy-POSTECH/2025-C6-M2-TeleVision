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

    // Convenience initializer that constructs default dependencies on the main actor,
    // then forwards to the designated initializer above.
    @MainActor
    public convenience init() {
        let local = PatientLocalDataSourceJSON()
        let remote = PatientRemoteDataSourceCloudKit()
        self.init(localDataSource: local, remoteDataSource: remote)
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

    // MARK: - Case Operations

    public func upsertCase(patientID: PatientID, case: Case) async throws {
        var patients = try await localDataSource.fetchAll()
        guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
            throw RepositoryError.notFound
        }

        var patient = patients[patientIndex]
        var updatedCase = `case`
        updatedCase.updatedAt = Date()

        if let caseIndex = patient.cases.firstIndex(where: { $0.id == `case`.id }) {
            patient.cases[caseIndex] = updatedCase
        } else {
            patient.cases.append(updatedCase)
        }

        patient.updatedAt = Date()
        patients[patientIndex] = patient

        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, patient] in
            try? await self?.remoteDataSource.push(patient)
        }
    }

    public func deleteCase(patientID: PatientID, caseID: CaseID) async throws {
        var patients = try await localDataSource.fetchAll()
        guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
            throw RepositoryError.notFound
        }

        var patient = patients[patientIndex]
        patient.cases.removeAll { $0.id == caseID }
        patient.updatedAt = Date()
        patients[patientIndex] = patient

        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, patient] in
            try? await self?.remoteDataSource.push(patient)
        }
    }

    // MARK: - Model Operations

    public func attachModelToCase(patientID: PatientID, caseID: CaseID, file: ModelFile) async throws {
        var patients = try await localDataSource.fetchAll()
        guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
            throw RepositoryError.notFound
        }

        var patient = patients[patientIndex]
        guard let caseIndex = patient.cases.firstIndex(where: { $0.id == caseID }) else {
            throw RepositoryError.notFound
        }

        var `case` = patient.cases[caseIndex]
        `case`.models.append(file)
        `case`.updatedAt = Date()
        patient.cases[caseIndex] = `case`
        patient.updatedAt = Date()
        patients[patientIndex] = patient

        try await localDataSource.saveAll(patients)

        // Background sync to remote
        Task.detached { [weak self, patient] in
            try? await self?.remoteDataSource.push(patient)
        }
    }

    public func removeModelFromCase(patientID: PatientID, caseID: CaseID, modelID: ModelID) async throws {
        var patients = try await localDataSource.fetchAll()
        guard let patientIndex = patients.firstIndex(where: { $0.id == patientID }) else {
            throw RepositoryError.notFound
        }

        var patient = patients[patientIndex]
        guard let caseIndex = patient.cases.firstIndex(where: { $0.id == caseID }) else {
            throw RepositoryError.notFound
        }

        var `case` = patient.cases[caseIndex]
        `case`.models.removeAll { $0.id == modelID }
        `case`.updatedAt = Date()
        patient.cases[caseIndex] = `case`
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
