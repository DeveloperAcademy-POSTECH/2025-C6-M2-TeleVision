//
//  PatientInfoHeader.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct PatientInfoHeader: View {
    @Environment(OperationViewModel.self) var dataViewModel
    
    private var patient: PatientDisplayModel {
        dataViewModel.state.patient ?? PatientDisplayModel.MockData
    }
    

    var body: some View {
        HStack {
            Text(patient.name)
                .font(.system(size: 10))
                .foregroundStyle(.primary)
            Spacer().frame(width: 4)
            Text("\(patient.genderText) / \(patient.ageText)")
                .font(.system(size: 8))
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    PatientInfoHeader()
}
