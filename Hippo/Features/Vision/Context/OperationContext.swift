//
//  OperationContext.swift
//  HippoVision
//
//  Created by 김현기 on 10/22/25.
//

import Foundation

/// OperationContext
@MainActor
@Observable
class OperationContext {
    public let id: String
    public let operation: OperationDisplayModel
    public let patient: PatientDisplayModel

    public init(operation: OperationDisplayModel, patient: PatientDisplayModel) {
        id = operation.id
        self.operation = operation
        self.patient = patient
    }
}
