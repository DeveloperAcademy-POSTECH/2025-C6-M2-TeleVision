//
//  PatientSectionView.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 환자 목록 섹션
struct PatientSectionView: View {
    let patients: [PatientDisplayModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Patient List")
                .padding(.top, 24)

            PatientGridView(patients: patients)
        }
    }
}

#Preview {
    PatientSectionView(patients: [])
}
