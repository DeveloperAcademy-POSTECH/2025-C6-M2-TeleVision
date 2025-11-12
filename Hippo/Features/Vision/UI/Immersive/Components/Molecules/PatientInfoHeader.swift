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
                .font(.extraLargeTitle2)
                .foregroundStyle(.primary)
            Spacer().frame(width: 10)
            Text("\(patient.genderText) / \(patient.ageText)")
                .font(.title)
                .foregroundStyle(.primary)
        }
    }
}

#Preview {
    PatientInfoHeader()
}
