import Foundation

/// Operation status value object
public enum OperationStatus: String, Codable, Sendable {
  case planned
  case inProgress
  case completed
  case cancelled
}
