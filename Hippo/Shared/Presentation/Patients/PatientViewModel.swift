import Dependencies
import Foundation
import Observation

@MainActor
@Observable
public final class PatientViewModel {
    // MARK: - Dependencies
    @ObservationIgnored
    @Dependency(\.listPatients) private var listPatients

    @ObservationIgnored
    @Dependency(\.upsertPatient) private var upsertPatient

    @ObservationIgnored
    @Dependency(\.deletePatient) private var deletePatient

    @ObservationIgnored
    @Dependency(\.upsertCase) private var upsertCase

    @ObservationIgnored
    @Dependency(\.deleteCase) private var deleteCase

    @ObservationIgnored
    @Dependency(\.attachModelToCase) private var attachModelToCase

    @ObservationIgnored
    @Dependency(\.removeModelFromCase) private var removeModelFromCase

    // MARK: - State
    public var state: PatientState

    public init(state: PatientState = PatientState(items: [], isLoading: false, alert: nil)) {
        self.state = state
    }

    // MARK: - Actions

    public func load() async {
        state.isLoading = true
        state.alert = nil

        do {
            let patients = try await listPatients.run()
            state.items = patients
        } catch {
            state.alert = "Failed to load patients: \(error.localizedDescription)"
        }

        state.isLoading = false
    }

    public func create(name: String, sex: Sex = .unknown, birthDate: Date? = nil, mrn: String? = nil) async {
        let newPatient = Patient(
            name: name,
            sex: sex,
            birthDate: birthDate,
            mrn: mrn
        )

        do {
            let savedPatient = try await upsertPatient.run(newPatient)
            state.items.append(savedPatient)
            state.items.sort { $0.updatedAt > $1.updatedAt }
        } catch {
            state.alert = "Failed to create patient: \(error.localizedDescription)"
        }
    }

    public func update(_ patient: Patient) async {
        do {
            let updatedPatient = try await upsertPatient.run(patient)
            if let index = state.items.firstIndex(where: { $0.id == patient.id }) {
                state.items[index] = updatedPatient
                state.items.sort { $0.updatedAt > $1.updatedAt }
            }
        } catch {
            state.alert = "Failed to update patient: \(error.localizedDescription)"
        }
    }

    public func remove(_ patient: Patient) async {
        do {
            try await deletePatient.run(patient.id)
            state.items.removeAll { $0.id == patient.id }
        } catch {
            state.alert = "Failed to delete patient: \(error.localizedDescription)"
        }
    }

    // MARK: - Case Management

    public func addCase(to patient: Patient, title: String, diagnosis: String) async {
        let newCase = Case(
            title: title,
            diagnosis: diagnosis
        )

        do {
            try await upsertCase.run(UpsertCase.Input(patientID: patient.id, case: newCase))
            await load() // Reload to get updated data
        } catch {
            state.alert = "Failed to add case: \(error.localizedDescription)"
        }
    }

    public func removeCase(_ caseItem: Case, from patient: Patient) async {
        do {
            try await deleteCase.run(DeleteCase.Input(patientID: patient.id, caseID: caseItem.id))
            await load() // Reload to get updated data
        } catch {
            state.alert = "Failed to remove case: \(error.localizedDescription)"
        }
    }

    // MARK: - Model Management

    public func attachModel(_ file: ModelFile, toCase caseItem: Case, in patient: Patient) async {
        do {
            try await attachModelToCase.run(
                AttachModelToCase.Input(patientID: patient.id, caseID: caseItem.id, file: file)
            )
            await load() // Reload to get updated data
        } catch {
            state.alert = "Failed to attach model: \(error.localizedDescription)"
        }
    }

    public func removeModel(_ modelID: ModelID, fromCase caseItem: Case, in patient: Patient) async {
        do {
            try await removeModelFromCase.run(
                RemoveModelFromCase.Input(patientID: patient.id, caseID: caseItem.id, modelID: modelID)
            )
            await load() // Reload to get updated data
        } catch {
            state.alert = "Failed to remove model: \(error.localizedDescription)"
        }
    }

    public func dismissAlert() {
        state.alert = nil
    }
}
