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

