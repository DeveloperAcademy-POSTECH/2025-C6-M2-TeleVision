//
//  OperationDetailView.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct OperationDetailView: View {
    @State private var viewModel = AppModel()
    let patient: PatientDisplayModel
    let operation: OperationDisplayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailHeader(operation: operation, onClose: {})
                .padding(.horizontal, 32)
                .padding(.top, 32)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // 모델 이미지
                    AssetSection()

                    // 수술 상세 정보
                    DetailSubPart(
                        title: "수술 상세",
                        content: operation.details
                    )

                    // 환자 정보
                    DetailSubPart(
                        title: "환자 정보",
                        content: "\(patient.name) (\(patient.gender) / \(patient.ageText))"
                    )

                    // 집도의 정보
                    DetailSubPart(
                        title: "집도의",
                        content: operation.surgeon
                    )

                    // 수술 부위 정보
                    DetailSubPart(
                        title: "수술 부위",
                        content: "여기 수정해야함"
                    )

                    // 진단(병명) 정보
                    DetailSubPart(
                        title: "진단(병명)",
                        content: operation.diagnosis
                    )

                    // 수술 날짜 정보
                    DetailSubPart(
                        title: "수술 날짜",
                        content: operation.dateText
                    )
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        .onDisappear {
            viewModel.state.selectedPatient = nil
        }
    }
}

#Preview {
    OperationDetailView(patient: PatientDisplayModel.MockData)
}

