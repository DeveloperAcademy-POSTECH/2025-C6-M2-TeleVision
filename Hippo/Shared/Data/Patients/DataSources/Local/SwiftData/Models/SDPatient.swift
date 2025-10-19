import Foundation
import SwiftData

// MARK: - SDPatient (SwiftData Model - SSOT)

/// SwiftData model for Patient aggregate root
/// Primary Key: id (unique)
/// Unique Key: patientNumber (local uniqueness constraint)
@Model
final class SDPatient {
  @Attribute(.unique) var id: String
  @Attribute(.unique) var patientNumber: String
  var name: String
  var genderRaw: String // "male" | "female"
  var birthDate: Date
  var createdAt: Date
  var updatedAt: Date

  @Relationship(deleteRule: .cascade)
  var operations: [SDOperation] = []

  init(
    id: String,
    patientNumber: String,
    name: String,
    genderRaw: String,
    birthDate: Date,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.patientNumber = patientNumber
    self.name = name
    self.genderRaw = genderRaw
    self.birthDate = birthDate
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
