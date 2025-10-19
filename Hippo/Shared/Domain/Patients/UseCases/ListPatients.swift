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

