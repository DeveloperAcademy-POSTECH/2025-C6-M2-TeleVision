import Dependencies
import Foundation

public struct UpsertPatient: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ patient: Patient) async throws -> Patient {
        try await repository.upsertPatient(patient)
    }
}

// MARK: - Dependency
extension UpsertPatient: DependencyKey {
    public static let liveValue = UpsertPatient(
        repository: PatientRepositoryImpl()
    )

}

extension DependencyValues {
    public var upsertPatient: UpsertPatient {
        get { self[UpsertPatient.self] }
        set { self[UpsertPatient.self] = newValue }
    }
}

