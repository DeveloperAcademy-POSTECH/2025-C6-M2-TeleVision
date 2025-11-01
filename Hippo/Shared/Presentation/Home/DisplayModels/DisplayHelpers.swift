import Foundation

// MARK: - Display Helpers

/// Domain Value Objects의 UI 표시 헬퍼

// MARK: - Gender Display

public extension Gender {
    var displayText: String {
        switch self {
        case .male: return "M"
        case .female: return "F"
        }
    }

    var iconName: String {
        switch self {
        case .male: return "person.fill"
        case .female: return "person.fill"
        }
    }
}

// MARK: - OperationStatus Display

public extension OperationStatus {
    var displayText: String {
        switch self {
        case .planned: return "수술 대기"
        case .inProgress: return "수술 중"
        case .completed: return "수술 완료"
        case .cancelled: return "수술 취소"
        }
    }

    var colorName: String {
        switch self {
        case .planned: return "HippoRed"
        case .inProgress: return "orange"
        case .completed: return "HippoBlack"
        case .cancelled: return "gray"
        }
    }
}

// MARK: - OperationAssetExtension Display (현재 사용하지 않음)

// public extension OperationAssetExtension {
//    var iconName: String {
//        switch self {
//        case .usdz: return "cube.fill"
//        case .usdc: return "cube.fill"
//        case .others: return "doc.fill"
//        }
//    }
// }
