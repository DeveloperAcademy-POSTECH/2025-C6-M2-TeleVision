import Dependencies
import Foundation

public struct UpsertOperation: Sendable {
  public struct Input: Sendable {
    public let patientID: String
    public let operation: Operation

    public init(patientID: String, operation: Operation) {
      self.patientID = patientID
      self.operation = operation
    }
  }

  private let repository: PatientRepository

  public init(repository: PatientRepository) {
    self.repository = repository
  }

  public func run(_ input: Input) async throws {
    try await repository.upsertOperation(patientID: input.patientID, operation: input.operation)
  }
}

// MARK: - Dependency
extension UpsertOperation: DependencyKey {
  public static let liveValue = UpsertOperation(
    repository: PatientRepositoryImpl()
  )
}

extension DependencyValues {
  public var upsertOperation: UpsertOperation {
    get { self[UpsertOperation.self] }
    set { self[UpsertOperation.self] = newValue }
  }
}
