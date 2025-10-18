import Dependencies
import Foundation

public struct ListPatients: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run() async throws -> [Patient] {
        try await repository.listPatients()
    }
}

// MARK: - Dependency
extension ListPatients: DependencyKey {
    public static let liveValue = ListPatients(
        repository: PatientRepositoryImpl()
    )
}

extension DependencyValues {
    public var listPatients: ListPatients {
        get { self[ListPatients.self] }
        set { self[ListPatients.self] = newValue }
    }
}

