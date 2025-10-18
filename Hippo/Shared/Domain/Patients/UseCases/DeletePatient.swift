import Dependencies
import Foundation

public struct DeletePatient: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ id: String) async throws {
        try await repository.deletePatient(id: id)
    }
}

// MARK: - Dependency
extension DeletePatient: DependencyKey {
    public static let liveValue = DeletePatient(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var deletePatient: DeletePatient {
        get { self[DeletePatient.self] }
        set { self[DeletePatient.self] = newValue }
    }
}

