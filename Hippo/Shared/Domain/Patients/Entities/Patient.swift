import Foundation

// MARK: - Patient Entity (Aggregate Root)

public struct Patient: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public var patientNumber: String
  public var name: String
  public var gender: Gender
  public var birthDate: Date
  public var operations: [Operation]
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString,
    patientNumber: String,
    name: String,
    gender: Gender,
    birthDate: Date,
    operations: [Operation] = [],
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.patientNumber = patientNumber
    self.name = name
    self.gender = gender
    self.birthDate = birthDate
    self.operations = operations
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// Computed age from birthDate
  public var age: Int {
    Calendar(identifier: .gregorian)
      .dateComponents([.year], from: birthDate, to: Date()).year ?? 0
  }

  /// Create a copy with updated timestamp
  public func withUpdatedTimestamp() -> Patient {
    var copy = self
    copy.updatedAt = Date()
    return copy
  }
}
