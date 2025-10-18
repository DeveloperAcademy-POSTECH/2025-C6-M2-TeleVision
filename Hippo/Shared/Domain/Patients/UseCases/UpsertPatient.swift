import Foundation

public struct UpsertPatient: Sendable {
    private let repository: PatientRepository

    public init(repository: PatientRepository) {
        self.repository = repository
    }

    public func run(_ patient: Patient) async throws -> Patient {
        // Update timestamp before saving (business logic)
        let patientToSave = patient.withUpdatedTimestamp()
        return try await repository.upsertPatient(patientToSave)
    }
}

