import Foundation

// MARK: - Patient Display Model
/// View 레이어 전용 Patient 모델
public struct PatientDisplayModel: Identifiable, Equatable, Sendable {
  public let id: String
  public let patientNumber: String
  public let name: String
  public let gender: String
  public let genderIcon: String
  public let age: Int
  public let ageText: String
  public let birthDateText: String
  public let operations: [OperationDisplayModel]
  public let operationCount: Int
  public let updatedAt: Date
  public let updatedAtText: String

  public init(
    id: String,
    patientNumber: String,
    name: String,
    gender: String,
    genderIcon: String,
    age: Int,
    ageText: String,
    birthDateText: String,
    operations: [OperationDisplayModel],
    operationCount: Int,
    updatedAt: Date,
    updatedAtText: String
  ) {
    self.id = id
    self.patientNumber = patientNumber
    self.name = name
    self.gender = gender
    self.genderIcon = genderIcon
    self.age = age
    self.ageText = ageText
    self.birthDateText = birthDateText
    self.operations = operations
    self.operationCount = operationCount
    self.updatedAt = updatedAt
    self.updatedAtText = updatedAtText
  }
}
