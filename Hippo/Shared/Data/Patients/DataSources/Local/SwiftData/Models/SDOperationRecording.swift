import Foundation
import SwiftData

// MARK: - SDOperationRecording (SwiftData Model)

/// SwiftData model for OperationRecording entity
/// Primary Key: id (unique)
@Model
final class SDOperationRecording {
  @Attribute(.unique) var id: String
  var fileURLString: String // absolute URL string

  var operation: SDOperation?

  init(id: String, fileURLString: String) {
    self.id = id
    self.fileURLString = fileURLString
  }
}
