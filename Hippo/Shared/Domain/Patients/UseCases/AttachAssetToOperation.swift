import Dependencies
import Foundation

public struct AttachAssetToOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operationID: String
    public let asset: OperationAsset

    public init(patientID: String, operationID: String, asset: OperationAsset) {
      self.patientID = patientID
      self.operationID = operationID
      self.asset = asset
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    try await repository.attachAssetToOperation(
      patientID: input.patientID,
      operationID: input.operationID,
      asset: input.asset
    )
  }
}

// MARK: - Dependency
extension AttachAssetToOperation: DependencyKey {
  public static let liveValue = AttachAssetToOperation(
    repository: PatientRepositoryImpl()
  )
}

extension DependencyValues {
  public var attachAssetToOperation: AttachAssetToOperation {
    get { self[AttachAssetToOperation.self] }
    set { self[AttachAssetToOperation.self] = newValue }
  }
}
