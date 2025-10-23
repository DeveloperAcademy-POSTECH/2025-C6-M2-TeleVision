//
//  OperationState.swift
//  Hippo
//
//  Created by 김현기 on 10/24/25.
//

import Foundation
import Observation

/// State for Patient list view
@MainActor
@Observable
public final class OperationState {
    public var patient: PatientDisplayModel?
    public var operation: OperationDisplayModel?
    public var isLoading: Bool
    public var alert: String?

    public init(
        patient: PatientDisplayModel? = nil,
        operation: OperationDisplayModel? = nil,
        isLoading: Bool = false,
        alert: String? = nil,
    ) {
        self.patient = patient
        self.operation = operation
        self.isLoading = isLoading
        self.alert = alert
    }
}
