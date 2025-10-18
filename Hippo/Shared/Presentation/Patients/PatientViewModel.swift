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
    @Dependency(\.upsertOperation) private var upsertOperation

    @ObservationIgnored
    @Dependency(\.deleteOperation) private var deleteOperation

    @ObservationIgnored
    @Dependency(\.attachModelToOperation) private var attachModelToOperation

    @ObservationIgnored
    @Dependency(\.removeModelFromOperation) private var removeModelFromOperation

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

    // MARK: - Operation Management

    public func addOperation(to patient: Patient, title: String, diagnosis: String, surgeon: String = "", scheduledAt: Date? = nil, detail: String? = nil) async {
        let newOperation = Operation(
            title: title,
            diagnosis: diagnosis,
            surgeon: surgeon,
            scheduledAt: scheduledAt,
            detail: detail
        )

        do {
            try await upsertOperation.run(UpsertOperation.Input(patientID: patient.id, operation: newOperation))
            await load() // Reload to get updated data
        } catch {
            state.alert = "Failed to add operation: \(error.localizedDescription)"
        }
    }

    public func removeOperation(_ operation: Operation, from patient: Patient) async {
        do {
            try await deleteOperation.run(DeleteOperation.Input(patientID: patient.id, operationID: operation.id))
            await load() // Reload to get updated data
        } catch {
            state.alert = "Failed to remove operation: \(error.localizedDescription)"
        }
    }

    // MARK: - Model Management

    public func attachModel(_ file: OperationAsset, to operation: Operation, in patient: Patient) async {
        do {
            try await attachModelToOperation.run(
                AttachModelToOperation.Input(patientID: patient.id, operationID: operation.id, file: file)
            )
            await load() // Reload to get updated data
        } catch {
            state.alert = "Failed to attach model: \(error.localizedDescription)"
        }
    }

    public func removeModel(_ assetID: AssetID, from operation: Operation, in patient: Patient) async {
        do {
            try await removeModelFromOperation.run(
                RemoveModelFromOperation.Input(patientID: patient.id, operationID: operation.id, assetID: assetID)
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
