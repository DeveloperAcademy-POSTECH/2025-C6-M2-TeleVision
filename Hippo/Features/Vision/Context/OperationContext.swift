//
//  OperationContext.swift
//  HippoVision
//
//  Created by 김현기 on 10/23/25.
//

import SwiftUI

struct OperationContext: Identifiable, Hashable, Codable {
    let id: String
    let patientID: String
    let operationID: String
    
    init(patientID: String, operationID: String) {
        self.id = operationID
        self.patientID = patientID
        self.operationID = operationID
    }
}
