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

