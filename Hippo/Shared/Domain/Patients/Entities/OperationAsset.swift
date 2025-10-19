import Foundation

// MARK: - OperationAsset Entity
// Entity: lifecycle/stateful (CKAsset linkage, replacement/version possible)

public struct OperationAsset: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var name: String
  public var fileExtension: OperationAssetExtension
  public var fileURL: URL

  public init(
    id: String,
    name: String,
    fileExtension: OperationAssetExtension,
    fileURL: URL
  ) {
    self.id = id
    self.name = name
    self.fileExtension = fileExtension
    self.fileURL = fileURL
  }
}
