//
//  OperationViewModel.swift
//  HippoVision
//
//  Created by 김현기 on 10/23/25.
//

import Dependencies
import os.log
import SwiftUI

@MainActor
@Observable
public final class OperationViewModel {
    public init() {}

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.getPatient) private var getPatient

    @ObservationIgnored
    @Dependency(\.getOperation) private var getOperation

    @ObservationIgnored
    @Dependency(\.createOperation) private var createOperation

    @ObservationIgnored
    @Dependency(\.upsertOperation) private var upsertOperation

    @ObservationIgnored
    @Dependency(\.deleteOperation) private var deleteOperation

    @ObservationIgnored
    @Dependency(\.removeAssetFromOperation) private var removeAssetFromOperation

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "OperationViewModel")

    // MARK: - State

    private let _state = OperationState()
    public var state: OperationState { _state } // 읽기 전용, 관찰 가능

    // MARK: - UI State (Accessible)

    // 수술 전
    public var operationTitle: String = ""
    public var operationDiagnosis: String = ""
    public var operationSurgeon: String = ""
    public var surgicalSite: String = ""
    public var operationDate: Date = .init()
    public var operationDetail: String = ""
    public var operation3DAssets: [OperationAsset] = []

    init(patientID: String, operationID: String) {
        Task {
            do {
                // Load patient
                let patient = try await getPatient.run(patientID)
                let patientDisplayModel = patient.toDisplayModel()
                _state.patient = patientDisplayModel

                // Load operation
                let operation = try await getOperation.run(
                    GetOperation.Input(patientID: patientID, operationID: operationID)
                )

                // Set UI properties
                self.operationTitle = operation.title
                self.operationDiagnosis = operation.diagnosis
                self.operationSurgeon = operation.surgeon
                self.operationDate = operation.date
                self.operationDetail = operation.details
                self.operation3DAssets = operation.operationAssets

                // Set state
                _state.operation = operation.toDisplayModel()

                logger.debug("OperationViewModel initialized with patientID: \(patientID), operationID: \(operationID)")
            } catch {
                logger.error("Failed to initialize OperationViewModel: \(error.localizedDescription)")
                _state.alert = "Failed to load operation data: \(error.localizedDescription)"
            }
        }
    }

    public var isShowingFilePicker: Bool = false
    public var isShowingEditInputView: Bool = false
    public var isModelFileSelected: Bool = false

    // 수술 중
    public var isMenuActive: Bool = true
    public var isEndoscopicActive: Bool = false
    public var isShowingFinishAlert: Bool = false
    public var isShowingAssetListView: Bool = false

    // MARK: - Actions

    public func load(patientID: String, operationID: String) async {
        _state.isLoading = true
        _state.alert = nil

        do {
            // Load patient
            let patient = try await getPatient.run(patientID)
            logger.debug("Loaded \(patient.name) from repository")

            let patientDisplayModel = patient.toDisplayModel()
            _state.patient = patientDisplayModel

            // Load operation using GetOperation UseCase
            let operation = try await getOperation.run(
                GetOperation.Input(patientID: patientID, operationID: operationID)
            )
            _state.operation = operation.toDisplayModel()
            logger.debug("Loaded operation with ID \(operationID) for patient \(patient.name)")

        } catch {
            logger.error("Failed to load data with patientID: \(patientID), operationID: \(operationID), error: \(error.localizedDescription)")
            _state.alert = "Failed to load data: \(error.localizedDescription)"
        }

        _state.isLoading = false
    }

    public func addOperation(toPatientID patientID: String) async {
        do {
            let command = try CreateOperationCommand(
                title: operationTitle,
                diagnosis: operationDiagnosis,
                surgeon: operationSurgeon,
                surgicalSite: surgicalSite,
                date: operationDate,
                details: operationDetail,
                assets: operation3DAssets,
                status: .planned
            )

            try await createOperation.run(
                CreateOperation.Input(patientID: patientID, command: command)
            )

        } catch let validationError as ValidationError {
            _state.alert = validationError.localizedDescription
        } catch {
            _state.alert = "Failed to add operation: \(error.localizedDescription)"
        }
    }

    public func updateOperationStatus(to status: OperationStatus) async {
        do {
            if let patientID = state.patient?.id, let operationID = state.operation?.id {
                logger.debug("Attempting to update status with ID \(operationID) for patient ID \(patientID)")

                let command = try UpdateOperationCommand(
                    operationID: operationID,
                    status: status
                )

                try await upsertOperation.run(
                    UpsertOperation.Input(patientID: patientID, command: command)
                )

                // Reload operation from DB to update state
                let updatedOperation = try await getOperation.run(
                    GetOperation.Input(patientID: patientID, operationID: operationID)
                )
                _state.operation = updatedOperation.toDisplayModel()

                logger.debug("Operation status updated and state refreshed successfully.")
            }
        } catch let validationError as ValidationError {
            _state.alert = validationError.localizedDescription
        } catch {
            _state.alert = "Failed to update operation: \(error.localizedDescription)"
        }
    }

    // MARK: - Operation Input (Update, Delete)

    public func selectModelAsset(_ id: String) {
        state.selectedAssetID = id
    }

    public func deleteModelAsset(_ id: String) async {
        do {
            if let patientID = state.patient?.id, let operationID = state.operation?.id {
                try await removeAssetFromOperation.run(
                    RemoveAssetFromOperation.Input(
                        patientID: patientID,
                        operationID: operationID,
                        assetID: id
                    )
                )
            }
            state.selectedAssetID = nil
        } catch {
            _state.alert = "Failed to remove asset: \(error.localizedDescription)"
        }
    }

    public func updateOperation() async {
        do {
            if let patientID = state.patient?.id, let operationID = state.operation?.id {
                logger.debug("Attempting to update operation with ID \(operationID) for patient ID \(patientID)")

                let command = try UpdateOperationCommand(
                    operationID: operationID,
                    title: operationTitle,
                    diagnosis: operationDiagnosis,
                    surgeon: operationSurgeon,
                    date: operationDate,
                    details: operationDetail,
                    assets: operation3DAssets
                )

                try await upsertOperation.run(
                    UpsertOperation.Input(patientID: patientID, command: command)
                )

                // Reload operation from DB to update state
                let updatedOperation = try await getOperation.run(
                    GetOperation.Input(patientID: patientID, operationID: operationID)
                )
                _state.operation = updatedOperation.toDisplayModel()

                logger.debug("Operation updated and state refreshed successfully.")
            }
        } catch let validationError as ValidationError {
            _state.alert = validationError.localizedDescription
        } catch {
            _state.alert = "Failed to update operation: \(error.localizedDescription)"
        }
    }

    public func deleteOperation() async {
        do {
            if let patientID = state.patient?.id, let operationID = state.operation?.id {
                logger.debug("Attempting to delete operation with ID \(operationID) for patient ID \(patientID)")
                try await deleteOperation.run(
                    DeleteOperation.Input(patientID: patientID, operationID: operationID)
                )
                logger.debug("Operation deleted successfully.")
            }
        } catch let validationError as ValidationError {
            _state.alert = validationError.localizedDescription
        } catch {
            _state.alert = "Failed to delete operation: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions in Immersive Surgery Mode

    public func openEntityPanel() {}

    public func recordPassThroughVideo() {}
}
