import Foundation

/// OperationRepository 구현체
///
/// Operation 중심의 도메인 Facade로 동작하며,
/// 내부적으로 PatientRepository를 사용하여 데이터를 관리합니다.
///
/// - Note: Operation은 Patient Aggregate 내부 Entity이므로,
///         모든 작업은 Patient를 통해 수행됩니다.
public actor OperationRepositoryImpl: OperationRepository {
    private let patientRepository: PatientRepository

    public init(patientRepository: PatientRepository) {
        self.patientRepository = patientRepository
    }

    // MARK: - Operation CRUD

    public func listOperations(forPatientID patientID: String) async throws -> [Operation] {
        let patient = try await getPatientWithErrorMapping(id: patientID)
        return patient.operations
    }

    public func getOperation(id: String, inPatientID patientID: String) async throws -> Operation {
        let patient = try await getPatientWithErrorMapping(id: patientID)

        guard let operation = patient.operations.first(where: { $0.id == id }) else {
            throw OperationError.operationNotFound
        }

        return operation
    }

    public func createOperation(_ operation: Operation, forPatientID patientID: String) async throws -> Operation {
        var patient = try await getPatientWithErrorMapping(id: patientID)

        // Operation 추가
        patient.operations.append(operation)

        // Patient 타임스탬프 업데이트 및 저장
        let updatedPatient = patient.withUpdatedTimestamp()
        _ = try await patientRepository.upsertPatient(updatedPatient)

        return operation
    }

    public func updateOperation(_ operation: Operation, inPatientID patientID: String) async throws {
        var patient = try await getPatientWithErrorMapping(id: patientID)

        guard let index = patient.operations.firstIndex(where: { $0.id == operation.id }) else {
            throw OperationError.operationNotFound
        }

        // Operation 업데이트
        patient.operations[index] = operation

        // Patient 타임스탬프 업데이트 및 저장
        let updatedPatient = patient.withUpdatedTimestamp()
        _ = try await patientRepository.upsertPatient(updatedPatient)
    }

    public func deleteOperation(id: String, fromPatientID patientID: String) async throws {
        var patient = try await getPatientWithErrorMapping(id: patientID)

        // Operation 제거 및 실제 제거 여부 확인
        let originalCount = patient.operations.count
        patient.operations.removeAll { $0.id == id }

        guard patient.operations.count < originalCount else {
            throw OperationError.operationNotFound
        }

        // Patient 타임스탬프 업데이트 및 저장
        let updatedPatient = patient.withUpdatedTimestamp()
        _ = try await patientRepository.upsertPatient(updatedPatient)
    }

    // MARK: - Operation Status

    public func updateOperationStatus(
        operationID: String,
        inPatientID patientID: String,
        status: OperationStatus
    ) async throws {
        var patient = try await getPatientWithErrorMapping(id: patientID)

        guard let index = patient.operations.firstIndex(where: { $0.id == operationID }) else {
            throw OperationError.operationNotFound
        }

        // 상태 업데이트
        patient.operations[index].status = status

        // Patient 타임스탬프 업데이트 및 저장
        let updatedPatient = patient.withUpdatedTimestamp()
        _ = try await patientRepository.upsertPatient(updatedPatient)
    }

    // MARK: - Asset Management

    public func addAssets(
        _ assets: [OperationAsset],
        toOperationID operationID: String,
        inPatientID patientID: String
    ) async throws {
        // PatientRepository에 위임 (에러 매핑 포함)
        do {
            try await patientRepository.addAssets(
                assets,
                toOperationID: operationID,
                inPatientID: patientID
            )
        } catch {
            try mapPatientError(error)
        }
    }

    public func removeAsset(
        _ assetID: String,
        fromOperationID operationID: String,
        inPatientID patientID: String
    ) async throws {
        // PatientRepository에 위임 (에러 매핑 포함)
        do {
            try await patientRepository.removeAsset(
                assetID,
                fromOperationID: operationID,
                inPatientID: patientID
            )
        } catch {
            try mapPatientError(error)
        }
    }

    public func getAssets(
        forOperationID operationID: String,
        inPatientID patientID: String
    ) async throws -> [OperationAsset] {
        // PatientRepository에 위임 (에러 매핑 포함)
        do {
            return try await patientRepository.getAssets(
                forOperationID: operationID,
                inPatientID: patientID
            )
        } catch {
            try mapPatientError(error)
        }
    }

    // MARK: - Recording Management

    public func addRecording(
        _ recording: OperationRecording,
        toOperationID operationID: String,
        inPatientID patientID: String
    ) async throws {
        var patient = try await getPatientWithErrorMapping(id: patientID)

        guard let index = patient.operations.firstIndex(where: { $0.id == operationID }) else {
            throw OperationError.operationNotFound
        }

        // Recording 추가
        patient.operations[index].recordings.append(recording)

        // Patient 타임스탬프 업데이트 및 저장
        let updatedPatient = patient.withUpdatedTimestamp()
        _ = try await patientRepository.upsertPatient(updatedPatient)
    }

    public func removeRecording(
        _ recordingID: String,
        fromOperationID operationID: String,
        inPatientID patientID: String
    ) async throws {
        var patient = try await getPatientWithErrorMapping(id: patientID)

        guard let index = patient.operations.firstIndex(where: { $0.id == operationID }) else {
            throw OperationError.operationNotFound
        }

        // Recording 제거 및 실제 제거 여부 확인
        let originalCount = patient.operations[index].recordings.count
        patient.operations[index].recordings.removeAll { $0.id == recordingID }

        guard patient.operations[index].recordings.count < originalCount else {
            throw OperationError.recordingNotFound
        }

        // Patient 타임스탬프 업데이트 및 저장
        let updatedPatient = patient.withUpdatedTimestamp()
        _ = try await patientRepository.upsertPatient(updatedPatient)
    }

    public func getRecordings(
        forOperationID operationID: String,
        inPatientID patientID: String
    ) async throws -> [OperationRecording] {
        let patient = try await getPatientWithErrorMapping(id: patientID)

        guard let operation = patient.operations.first(where: { $0.id == operationID }) else {
            throw OperationError.operationNotFound
        }

        return operation.recordings
    }

    // MARK: - Query

    public func getOperations(forDate date: Date) async throws -> [OperationWithPatient] {
        let allPatients = try await patientRepository.listPatients()

        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)

        var result: [OperationWithPatient] = []

        for patient in allPatients {
            let matchingOperations = patient.operations.filter { operation in
                let operationDay = calendar.startOfDay(for: operation.date)
                return operationDay == targetDay
            }

            for operation in matchingOperations {
                result.append(OperationWithPatient(patient: patient, operation: operation))
            }
        }

        return result
    }

    public func getOperations(byStatus status: OperationStatus) async throws -> [OperationWithPatient] {
        let allPatients = try await patientRepository.listPatients()

        var result: [OperationWithPatient] = []

        for patient in allPatients {
            let matchingOperations = patient.operations.filter { $0.status == status }

            for operation in matchingOperations {
                result.append(OperationWithPatient(patient: patient, operation: operation))
            }
        }

        return result
    }

    // MARK: - Private Helpers

    /// PatientRepository 호출 시 에러 매핑을 수행하는 helper 메서드
    /// PatientError를 OperationError로 변환합니다.
    private func getPatientWithErrorMapping(id: String) async throws -> Patient {
        do {
            return try await patientRepository.getPatient(id: id)
        } catch let error as PatientError {
            switch error {
            case .patientNotFound:
                throw OperationError.patientNotFound
            case .operationNotFound:
                throw OperationError.operationNotFound
            case .assetNotFound:
                throw OperationError.assetNotFound
            }
        } catch {
            throw error
        }
    }

    /// Asset 관련 PatientRepository 호출 시 에러 매핑
    private func mapPatientError(_ error: Error) throws {
        if let patientError = error as? PatientError {
            switch patientError {
            case .patientNotFound:
                throw OperationError.patientNotFound
            case .operationNotFound:
                throw OperationError.operationNotFound
            case .assetNotFound:
                throw OperationError.assetNotFound
            }
        }
        throw error
    }
}
