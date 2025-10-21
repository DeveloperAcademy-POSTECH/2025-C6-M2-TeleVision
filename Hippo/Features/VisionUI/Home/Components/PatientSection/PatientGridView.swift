//
//  PatientGridView.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 환자 카드 그리드
struct PatientGridView: View {
    let patients: [PatientDisplayModel]

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 200), spacing: 24, alignment: .top)]
    }

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
            ForEach(patients) { patient in
                PatientCell(patient: patient)
            }
        }
    }
}

#Preview {
    PatientGridView(patients: [])
}
