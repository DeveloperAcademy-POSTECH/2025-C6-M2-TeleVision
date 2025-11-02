import SwiftUI

// MARK: - Display Helpers

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

    var displayColor: Color {
        switch self {
        case .planned: return Color("HippoRed")
        case .inProgress: return .orange
        case .completed: return Color("HippoBlack")
        case .cancelled: return .gray
        }
    }
}
