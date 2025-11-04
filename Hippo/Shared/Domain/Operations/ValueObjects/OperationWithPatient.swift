import Foundation

/// Operation과 연관된 Patient를 함께 담는 읽기 전용 Projection 타입
///
/// Query 결과로 사용되며, Operation 중심의 읽기 작업에서
/// 연관된 Patient 정보를 함께 제공합니다.
///
/// - Note: 향후 성능 최적화가 필요한 경우
///         `patient: Patient` 대신 `patient: PatientSummary` 같은
///         요약 타입으로 교체할 수 있습니다.
public struct OperationWithPatient: Sendable, Equatable {
    /// 연관된 환자 정보
    public let patient: Patient

    /// 수술 정보
    public let operation: Operation

    public init(patient: Patient, operation: Operation) {
        self.patient = patient
        self.operation = operation
    }
}
