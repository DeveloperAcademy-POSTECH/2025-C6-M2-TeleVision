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

            if patients.isEmpty {
                HStack(alignment: .center) {
                    Spacer()
                    VStack {
                        Spacer().frame(height: 250)
                        Text("등록된 환자가 없습니다")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("수술을 시작하려면 환자 정보를 입력해주세요")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            } else {
                PatientGridView(patients: patients)
            }
        }
    }
}

#Preview {
    PatientSectionView(patients: [])
}
