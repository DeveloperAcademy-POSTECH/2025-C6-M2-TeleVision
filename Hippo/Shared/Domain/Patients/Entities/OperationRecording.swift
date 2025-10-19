import Foundation

// MARK: - OperationRecording Entity
// Entity: lifecycle/stateful (recording → upload/retry → thumbnail/retention)

public struct OperationRecording: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var fileURL: URL

  public init(id: String, fileURL: URL) {
    self.id = id
    self.fileURL = fileURL
  }
}
