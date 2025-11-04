import Foundation

/// Repository interface for Operation domain operations
///
/// OperationRepository는 Operation 중심의 도메인 Facade로 동작합니다.
/// 내부적으로 PatientRepository를 사용하여 데이터를 관리하며,
/// Operation이 Patient Aggregate 내부 Entity라는 DDD 원칙을 유지합니다.
///
/// - Note: Operation은 독립적인 Aggregate Root가 아니므로,
///         모든 작업은 Patient를 통해 수행됩니다.
public protocol OperationRepository: Sendable {
    // MARK: - Operation CRUD

    /// 특정 Patient의 모든 Operations 조회
    /// - Parameter patientID: 환자 ID
    /// - Returns: Operation 배열
    /// - Throws: OperationError.patientNotFound
    func listOperations(forPatientID patientID: String) async throws -> [Operation]

    /// 특정 Operation 조회
    /// - Parameters:
    ///   - id: Operation ID
    ///   - patientID: 환자 ID
    /// - Returns: Operation
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func getOperation(id: String, inPatientID patientID: String) async throws -> Operation

    /// Operation 생성
    /// - Parameters:
    ///   - operation: 생성할 Operation 엔티티
    ///   - patientID: 환자 ID
    /// - Returns: 생성된 Operation
    /// - Throws: OperationError.patientNotFound
    func createOperation(_ operation: Operation, forPatientID patientID: String) async throws -> Operation

    /// Operation 수정
    /// - Parameters:
    ///   - operation: 수정할 Operation 엔티티
    ///   - patientID: 환자 ID
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func updateOperation(_ operation: Operation, inPatientID patientID: String) async throws

    /// Operation 삭제
    /// - Parameters:
    ///   - id: Operation ID
    ///   - patientID: 환자 ID
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func deleteOperation(id: String, fromPatientID patientID: String) async throws

    // MARK: - Operation Status

    /// Operation 상태 변경
    /// - Parameters:
    ///   - operationID: Operation ID
    ///   - patientID: 환자 ID
    ///   - status: 변경할 상태
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func updateOperationStatus(
        operationID: String,
        inPatientID patientID: String,
        status: OperationStatus
    ) async throws

    // MARK: - Asset Management

    /// Asset 추가
    /// - Parameters:
    ///   - assets: 추가할 Asset 배열
    ///   - operationID: Operation ID
    ///   - patientID: 환자 ID
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func addAssets(
        _ assets: [OperationAsset],
        toOperationID operationID: String,
        inPatientID patientID: String
    ) async throws

    /// Asset 제거
    /// - Parameters:
    ///   - assetID: Asset ID
    ///   - operationID: Operation ID
    ///   - patientID: 환자 ID
    /// - Throws: OperationError.assetNotFound, OperationError.operationNotFound
    func removeAsset(
        _ assetID: String,
        fromOperationID operationID: String,
        inPatientID patientID: String
    ) async throws

    /// Operation의 모든 Assets 조회
    /// - Parameters:
    ///   - operationID: Operation ID
    ///   - patientID: 환자 ID
    /// - Returns: OperationAsset 배열
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func getAssets(
        forOperationID operationID: String,
        inPatientID patientID: String
    ) async throws -> [OperationAsset]

    // MARK: - Recording Management

    /// Recording 추가
    /// - Parameters:
    ///   - recording: 추가할 Recording
    ///   - operationID: Operation ID
    ///   - patientID: 환자 ID
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func addRecording(
        _ recording: OperationRecording,
        toOperationID operationID: String,
        inPatientID patientID: String
    ) async throws

    /// Recording 제거
    /// - Parameters:
    ///   - recordingID: Recording ID
    ///   - operationID: Operation ID
    ///   - patientID: 환자 ID
    /// - Throws: OperationError.recordingNotFound, OperationError.operationNotFound
    func removeRecording(
        _ recordingID: String,
        fromOperationID operationID: String,
        inPatientID patientID: String
    ) async throws

    /// Operation의 모든 Recordings 조회
    /// - Parameters:
    ///   - operationID: Operation ID
    ///   - patientID: 환자 ID
    /// - Returns: OperationRecording 배열
    /// - Throws: OperationError.operationNotFound, OperationError.patientNotFound
    func getRecordings(
        forOperationID operationID: String,
        inPatientID patientID: String
    ) async throws -> [OperationRecording]

    // MARK: - Query

    /// 특정 날짜의 모든 Operations 조회
    ///
    /// - Parameter date: 조회할 날짜
    /// - Returns: OperationWithPatient 배열 (읽기 전용 Projection)
    /// - Note: 날짜는 Calendar.startOfDay 기준으로 비교됩니다.
    func getOperations(forDate date: Date) async throws -> [OperationWithPatient]

    /// 특정 상태의 모든 Operations 조회
    ///
    /// - Parameter status: Operation 상태
    /// - Returns: OperationWithPatient 배열 (읽기 전용 Projection)
    func getOperations(byStatus status: OperationStatus) async throws -> [OperationWithPatient]
}
