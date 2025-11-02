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
    @Dependency(\.addAssetsToOperation) private var addAssetsToOperation

    @ObservationIgnored
    @Dependency(\.createOperation) private var createOperation

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "PatientViewModel")

    // MARK: - State

    private let _state = OperationState()
    public var state: OperationState { _state } // 읽기 전용, 관찰 가능

    // MARK: - UI State (Accessible)

    // 수술 전
    public var operationTitle: String = ""
    public var operationDiagnosis: String = ""
    public var operationSurgeon: String = ""
    public var operationDate: Date = .init()
    public var operationDetail: String = ""
    public var operation3DFileURLs: [URL] = []

    public var isShowingFilePicker: Bool = false

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
            let patient = try await getPatient.run(patientID)
            logger.debug("🐛 Loaded \(patient.name) from repository")

            let patientDisplayModel = patient.toDisplayModel()
            _state.patient = patientDisplayModel

            await getOperation(id: operationID)
            logger.debug("🐛 Loaded operation with ID \(operationID) for patient \(patient.name)")

        } catch {
            logger.error("Failed to load patient with ID \(patientID), error: \(error.localizedDescription)")
            _state.alert = "Failed to load patient: \(error.localizedDescription)"
        }

        _state.isLoading = false
    }

    public func getOperation(id: String) async {
        if let patient = _state.patient {
            guard let operation = patient.operations.first(where: { $0.id == id }) else {
                logger.error("❌ Operation with ID \(id) not found for patient \(patient.name)")
                return
            }

            _state.operation = operation
        }
    }

    public func addOperation(toPatientID patientID: String) async {
        do {
            // 1. Operation 생성
            let command = try CreateOperationCommand(
                title: operationTitle,
                diagnosis: operationDiagnosis,
                surgeon: operationSurgeon,
                date: operationDate,
                details: operationDetail,
                status: .planned
            )

            let operation = try await createOperation.run(
                CreateOperation.Input(patientID: patientID, command: command)
            )

            // 2. OperationAsset 추가 (파일이 있는 경우)
            if !operation3DFileURLs.isEmpty {
                logger.debug("🐛 Adding assets to operation")

                // AddAssetsCommand 추가
                let assetsCommand = AddAssetsCommand(fileURLs: operation3DFileURLs)

                try await addAssetsToOperation.run(
                    AddAssetsToOperation.Input(
                        patientID: patientID,
                        operationID: operation.id,
                        command: assetsCommand
                    )
                )
            }

        } catch let validationError as ValidationError {
            _state.alert = validationError.localizedDescription
        } catch {
            _state.alert = "Failed to add operation: \(error.localizedDescription)"
        }
    }

    // MARK: - Actions in Immersive Surgery Mode

    public func openEntityPanel() {}

    public func recordPassThroughVideo() {}
}
