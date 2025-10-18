import Dependencies
import Foundation

public struct RemoveAssetFromOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operationID: String
    public let assetID: String

    public init(patientID: String, operationID: String, assetID: String) {
      self.patientID = patientID
      self.operationID = operationID
      self.assetID = assetID
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    try await repository.removeAssetFromOperation(
      patientID: input.patientID,
      operationID: input.operationID,
      assetID: input.assetID
    )
  }
}

// MARK: - Dependency
extension RemoveAssetFromOperation: DependencyKey {
  public static let liveValue = RemoveAssetFromOperation(
    repository: PatientRepositoryImpl()
  )
}

extension DependencyValues {
  public var removeAssetFromOperation: RemoveAssetFromOperation {
    get { self[RemoveAssetFromOperation.self] }
    set { self[RemoveAssetFromOperation.self] = newValue }
  }
}
