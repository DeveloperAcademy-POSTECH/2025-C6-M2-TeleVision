import Foundation

/// Operation 도메인에서 발생할 수 있는 에러 타입
public enum OperationError: Error, LocalizedError, Sendable {
    /// Operation을 찾을 수 없음
    case operationNotFound

    /// Operation이 속한 Patient를 찾을 수 없음
    case patientNotFound

    /// Asset을 찾을 수 없음
    case assetNotFound

    /// Recording을 찾을 수 없음
    case recordingNotFound

    /// 유효하지 않은 Operation 상태
    case invalidStatus

    /// 유효하지 않은 Operation 데이터
    case invalidOperation(reason: String)

    /// Asset 관련 에러
    case assetError(reason: String)

    /// Recording 관련 에러
    case recordingError(reason: String)

    public var errorDescription: String? {
        switch self {
        case .operationNotFound:
            return "수술 정보를 찾을 수 없습니다."
        case .patientNotFound:
            return "환자 정보를 찾을 수 없습니다."
        case .assetNotFound:
            return "자산을 찾을 수 없습니다."
        case .recordingNotFound:
            return "녹화 파일을 찾을 수 없습니다."
        case .invalidStatus:
            return "유효하지 않은 수술 상태입니다."
        case .invalidOperation(let reason):
            return "유효하지 않은 수술 정보입니다: \(reason)"
        case .assetError(let reason):
            return "자산 처리 중 오류가 발생했습니다: \(reason)"
        case .recordingError(let reason):
            return "녹화 처리 중 오류가 발생했습니다: \(reason)"
        }
    }
}
