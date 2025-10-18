import Foundation

// MARK: - PatientDTO
// Minimal sample DTO
public struct PatientDTO: Codable, Sendable {
  public let id: String

  public init(id: String) {
    self.id = id
  }
}
