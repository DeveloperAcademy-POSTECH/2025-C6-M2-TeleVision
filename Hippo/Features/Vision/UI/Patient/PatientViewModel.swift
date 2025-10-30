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

    public var patient: PatientDisplayModel?
    public var isPresentingOperationInput = false

    // MARK: - Action

    public func load(patientID: String) async {
        do {
            let p = try await getPatient.run(patientID)
            logger.debug("🐛 Loaded \(p.name) from repository")

            let patientDisplayModel = p.toDisplayModel()
            patient = patientDisplayModel

        } catch {
            logger.error("Failed to load patient with ID \(patientID), error: \(error.localizedDescription)")
        }
    }
}
