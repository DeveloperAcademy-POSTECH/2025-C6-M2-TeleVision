import Dependencies
import Foundation

public struct DeleteOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operationID: String

    public init(patientID: String, operationID: String) {
      self.patientID = patientID
      self.operationID = operationID
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    try await repository.deleteOperation(patientID: input.patientID, operationID: input.operationID)
  }
}

// MARK: - Dependency
extension DeleteOperation: DependencyKey {
  public static let liveValue = DeleteOperation(
    repository: PatientRepositoryImpl()
  )
}

extension DependencyValues {
  public var deleteOperation: DeleteOperation {
    get { self[DeleteOperation.self] }
    set { self[DeleteOperation.self] = newValue }
  }
}
