import Foundation
import SwiftData

// MARK: - SDPatient (SwiftData Model - SSOT)

/// SwiftData model for Patient aggregate root
/// Primary Key: id (unique)
/// Unique Key: patientNumber (local uniqueness constraint)
@Model
final class SDPatient {
    // CloudKit 제약조건 준수: 기본값 필수, Unique 제거, Optional 관계
    var id: String = UUID().uuidString
    var patientNumber: String = ""
    var name: String = ""
    var genderRaw: String = Gender.male.rawValue
    var birthDate: Date = Date()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \SDOperation.patient)
    var operations: [SDOperation]? = []

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
