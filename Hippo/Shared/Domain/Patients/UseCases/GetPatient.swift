import Dependencies
import Foundation

public struct GetPatient: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ id: String) async throws -> Patient {
        try await repository.getPatient(id: id)
    }
}

// MARK: - Dependency
extension GetPatient: DependencyKey {
    public static let liveValue = GetPatient(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var getPatient: GetPatient {
        get { self[GetPatient.self] }
        set { self[GetPatient.self] = newValue }
    }
}

