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
    public let latestOperation: OperationDisplayModel?
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
        latestOperation: OperationDisplayModel? = nil,
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
        self.latestOperation = latestOperation
        self.updatedAt = updatedAt
        self.updatedAtText = updatedAtText
    }

    // SAMPLE
    public static let MockData = PatientDisplayModel(
        id: "sample-001",
        patientNumber: "12345678",
        name: "김철수",
        gender: "남",
        genderIcon: "person.fill",
        age: 45,
        ageText: "45세",
        birthDateText: "1979.03.15",
        operations: [],
        operationCount: 1,
        latestOperation: nil,
        updatedAt: Date(),
        updatedAtText: "방금 전"
    )
}
