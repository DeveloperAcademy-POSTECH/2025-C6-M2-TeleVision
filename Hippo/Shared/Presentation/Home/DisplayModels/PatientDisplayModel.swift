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

    static let operation1 = OperationDisplayModel(
        id: "sample-op-001",
        title: "고관절 전치환술",
        diagnosis: "퇴행성 관절염",
        surgeon: "Dr. 홍길동",
        date: Date(),
        dateText: "2024.06.20",
        details: "환자는 70대 남성으로, 좌측 고관절의 심한 퇴행성 변화로 인해 전치환술을 시행하였습니다. 수술은 성공적으로 마무리되었으며, 현재 재활 치료 중입니다.",
        status: .planned,
        statusText: "수술 대기",
        statusColor: "HippoRed",
        assets: [],
        assetCount: 0,
    )

    static let operation2 = OperationDisplayModel(
        id: "sample-op-002",
        title: "간암 절제술",
        diagnosis: "간세포암",
        surgeon: "Dr. 이순신",
        date: Date(),
        dateText: "2024.05.15",
        details: "환자는 70대 남성으로, 좌측 고관절의 심한 퇴행성 변화로 인해 전치환술을 시행하였습니다. 수술은 성공적으로 마무리되었으며, 현재 재활 치료 중입니다.",
        status: .completed,
        statusText: "수술 완료",
        statusColor: "HippoBlack",
        assets: [],
        assetCount: 0,
    )

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
        operations: [operation1, operation2],
        operationCount: 2,
        latestOperation: nil,
        updatedAt: Date(),
        updatedAtText: "방금 전"
    )
}
