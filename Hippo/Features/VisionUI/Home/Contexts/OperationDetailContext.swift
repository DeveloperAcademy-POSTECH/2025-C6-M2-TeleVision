//
//  OperationDetailContext.swift
//  HippoVision
//
//  Created by 김현기 on 10/22/25.
//

import Foundation

public struct OperationDetailContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let operation: OperationDisplayModel
    public let patient: PatientDisplayModel

    public init(operation: OperationDisplayModel, patient: PatientDisplayModel) {
        id = operation.id
        self.operation = operation
        self.patient = patient
    }
}
