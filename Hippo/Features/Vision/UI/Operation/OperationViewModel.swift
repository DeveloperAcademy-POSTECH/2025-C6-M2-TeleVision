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

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "PatientViewModel")

    // MARK: - State

    private let _state = OperationState()
    public var state: OperationState { _state } // 읽기 전용, 관찰 가능

    // MARK: - UI State (Accessible)w

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

    // MARK: - Actions in Immersive Surgery Mode

    public func openEntityPanel() {}

    public func recordPassThroughVideo() {}
}
