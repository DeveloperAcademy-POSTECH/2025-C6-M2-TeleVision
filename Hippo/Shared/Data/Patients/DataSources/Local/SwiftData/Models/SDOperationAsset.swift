import Foundation
import SwiftData

// MARK: - SDOperationAsset (SwiftData Model)

/// SwiftData model for OperationAsset entity
/// Primary Key: id (unique)
@Model
final class SDOperationAsset {
  @Attribute(.unique) var id: String
  var name: String
  var fileExtensionRaw: String // "usdz" | "usdc" | "others"
  var fileURLString: String // absolute URL string

  var operation: SDOperation?

  init(
    id: String,
    name: String,
    fileExtensionRaw: String,
    fileURLString: String
  ) {
    self.id = id
    self.name = name
    self.fileExtensionRaw = fileExtensionRaw
    self.fileURLString = fileURLString
  }
}
