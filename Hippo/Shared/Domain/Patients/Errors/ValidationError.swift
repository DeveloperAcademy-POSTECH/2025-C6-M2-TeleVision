import Foundation

/// Validation error for command objects
public enum ValidationError: LocalizedError {
  case emptyField(String)
  case invalidField(String, String)

  public var errorDescription: String? {
    switch self {
    case .emptyField(let fieldName):
      return "\(fieldName.capitalized) cannot be empty"
    case .invalidField(let fieldName, let reason):
      return "\(fieldName.capitalized): \(reason)"
    }
  }
}
