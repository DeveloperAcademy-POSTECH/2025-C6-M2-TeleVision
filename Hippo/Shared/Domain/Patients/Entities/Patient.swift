import Foundation

public struct PatientID: Codable, Hashable, Sendable {
    public let value: String

    public init(value: String = UUID().uuidString) {
        self.value = value
    }
}

public enum Sex: String, Codable, Sendable {
    case male
    case female
    case other
    case unknown
}

public struct Patient: Codable, Sendable, Identifiable, Equatable {
    public let id: PatientID
    public var name: String
    public var sex: Sex
    public var birthDate: Date?
    public var mrn: String?
    public var cases: [Case]
    public var updatedAt: Date

    public init(
        id: PatientID = PatientID(),
        name: String,
        sex: Sex = .unknown,
        birthDate: Date? = nil,
        mrn: String? = nil,
        cases: [Case] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.sex = sex
        self.birthDate = birthDate
        self.mrn = mrn
        self.cases = cases
        self.updatedAt = updatedAt
    }

    /// Computed age from birthDate
    public var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year
    }
}
