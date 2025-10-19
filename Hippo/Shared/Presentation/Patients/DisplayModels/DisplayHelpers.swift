import Foundation

// MARK: - Display Helpers
/// Domain Value Objects의 UI 표시 헬퍼

// MARK: - Gender Display
extension Gender {
  public var displayText: String {
    switch self {
    case .male: return "Male"
    case .female: return "Female"
    }
  }

  public var iconName: String {
    switch self {
    case .male: return "person.fill"
    case .female: return "person.fill"
    }
  }
}

// MARK: - OperationStatus Display
extension OperationStatus {
  public var displayText: String {
    switch self {
    case .planned: return "Planned"
    case .inProgress: return "In Progress"
    case .completed: return "Completed"
    case .cancelled: return "Cancelled"
    }
  }

  public var colorName: String {
    switch self {
    case .planned: return "blue"
    case .inProgress: return "orange"
    case .completed: return "green"
    case .cancelled: return "gray"
    }
  }
}

// MARK: - OperationAssetExtension Display
extension OperationAssetExtension {
  public var iconName: String {
    switch self {
    case .usdz: return "cube.fill"
    case .usdc: return "cube.fill"
    case .others: return "doc.fill"
    }
  }
}
