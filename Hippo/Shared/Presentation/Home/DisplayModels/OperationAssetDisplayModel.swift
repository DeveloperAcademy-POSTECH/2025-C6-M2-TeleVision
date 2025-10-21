import Foundation

// MARK: - Operation Asset Display Model
/// View 레이어 전용 OperationAsset 모델
public struct OperationAssetDisplayModel: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let fileExtension: String
  public let fileURL: URL
  public let iconName: String

  public init(
    id: String,
    name: String,
    fileExtension: String,
    fileURL: URL,
    iconName: String
  ) {
    self.id = id
    self.name = name
    self.fileExtension = fileExtension
    self.fileURL = fileURL
    self.iconName = iconName
  }
}
