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

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "PatientViewModel")

    // MARK: - State

    public enum LoadingState {
        case idle
        case loading
        case loaded(PatientDisplayModel)
        case error(Error)
    }

    public var loadingState: LoadingState = .idle
    public var isPresentingOperationInput = false

    // MARK: - Computed Properties

    public var patient: PatientDisplayModel? {
        if case let .loaded(patient) = loadingState {
            return patient
        }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = loadingState {
            return true
        }
        return false
    }

    // MARK: - Action

    public func load(patientID: String) async {
        loadingState = .loading

        do {
            let p = try await getPatient.run(patientID)
            logger.debug("🐛 Loaded \(p.name) from repository")

            let patientDisplayModel = p.toDisplayModel()
            loadingState = .loaded(patientDisplayModel)

        } catch {
            logger.error("Failed to load patient with ID \(patientID), error: \(error.localizedDescription)")
            loadingState = .error(error)
        }
    }
}
