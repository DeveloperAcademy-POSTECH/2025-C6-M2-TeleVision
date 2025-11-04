//
//  PatientViewModel.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import Dependencies
import os.log
import SwiftUI

@MainActor
@Observable
public class PatientViewModel {
    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.getPatient) private var getPatient

    @ObservationIgnored
    @Dependency(\.deletePatient) private var deletePatient

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "PatientViewModel")

    // MARK: - State

    private let _state = PatientState()
    public var state: PatientState { _state }

    public var isPresentingOperationInput = false
    public var isShowingEditSheet = false

    // MARK: - Action

    public func load(patientID: String) async {
        state.isLoading = true
        state.error = nil

        do {
            let p = try await getPatient.run(patientID)
            logger.debug("🐛 Loaded \(p.name) from repository")

            state.patient = p.toDisplayModel()
            state.isLoading = false

        } catch {
            logger.error("Failed to load patient with ID \(patientID), error: \(error.localizedDescription)")
            state.isLoading = false
            state.error = .fetchFailed(error)
        }
    }

    public func deleteCurrentPatient() async {
        guard let patient = state.patient else { return }

        state.isLoading = true

        do {
            try await deletePatient.run(patient.id)
            logger.debug("🗑️ Deleted patient \(patient.name)")
            state.patient = nil
            state.isLoading = false

        } catch {
            logger.error("Failed to delete patient \(patient.id), error: \(error.localizedDescription)")
            state.isLoading = false
            state.error = .deleteFailed(error)
        }
    }
}
