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
  @Dependency(\.attachAssetToOperation) private var attachAssetToOperation

  @ObservationIgnored
  @Dependency(\.removeAssetFromOperation) private var removeAssetFromOperation

  // MARK: - State
  @ObservationIgnored
  public let state = PatientState()

  public init() {}

  // MARK: - Actions

  public func load() async {
    state.isLoading = true
    state.alert = nil

    do {
      let patients = try await listPatients.run()
      print("Loaded \(patients.count) patients from repository")
      let displayModels = patients.map { $0.toDisplayModel() }
      print("Converted to \(displayModels.count) display models")
      state.items = displayModels
      print("State updated with \(state.items.count) items")
    } catch {
      print("Failed to load patients: \(error)")
      state.alert = "Failed to load patients: \(error.localizedDescription)"
    }

    state.isLoading = false
  }

  public func create(
    patientNumber: String,
    name: String,
    gender: Gender,
    birthDate: Date
  ) async {
    let newPatient = Patient(
      patientNumber: patientNumber,
      name: name,
      gender: gender,
      birthDate: birthDate
    )

    do {
      _ = try await upsertPatient.run(newPatient)
      await load()
    } catch {
      state.alert = "Failed to create patient: \(error.localizedDescription)"
    }
  }

  public func update(_ patient: Patient) async {
    do {
      _ = try await upsertPatient.run(patient)
      await load()
    } catch {
      state.alert = "Failed to update patient: \(error.localizedDescription)"
    }
  }

  public func remove(patientID: String) async {
    do {
      try await deletePatient.run(patientID)
      await load()
    } catch {
      state.alert = "Failed to delete patient: \(error.localizedDescription)"
    }
  }

  // MARK: - Operation Management

  public func addOperation(
    to patient: Patient,
    title: String,
    diagnosis: String,
    surgeon: String,
    date: Date,
    details: String,
    status: OperationStatus
  ) async {
    let newOperation = Operation(
      id: UUID().uuidString,
      title: title,
      diagnosis: diagnosis,
      surgeon: surgeon,
      date: date,
      details: details,
      status: status
    )

    do {
      try await upsertOperation.run(
        UpsertOperation.Input(patientID: patient.id, operation: newOperation)
      )
      await load()
    } catch {
      state.alert = "Failed to add operation: \(error.localizedDescription)"
    }
  }

  public func removeOperation(_ operation: Operation, from patient: Patient) async {
    do {
      try await deleteOperation.run(
        DeleteOperation.Input(patientID: patient.id, operationID: operation.id)
      )
      await load()
    } catch {
      state.alert = "Failed to remove operation: \(error.localizedDescription)"
    }
  }

  // MARK: - Asset Management

  public func attachAsset(
    _ asset: OperationAsset,
    toOperation operation: Operation,
    in patient: Patient
  ) async {
    do {
      try await attachAssetToOperation.run(
        AttachAssetToOperation.Input(
          patientID: patient.id,
          operationID: operation.id,
          asset: asset
        )
      )
      await load()
    } catch {
      state.alert = "Failed to attach asset: \(error.localizedDescription)"
    }
  }

  public func removeAsset(
    _ assetID: String,
    fromOperation operation: Operation,
    in patient: Patient
  ) async {
    do {
      try await removeAssetFromOperation.run(
        RemoveAssetFromOperation.Input(
          patientID: patient.id,
          operationID: operation.id,
          assetID: assetID
        )
      )
      await load()
    } catch {
      state.alert = "Failed to remove asset: \(error.localizedDescription)"
    }
  }

  public func dismissAlert() {
    state.alert = nil
  }
}
