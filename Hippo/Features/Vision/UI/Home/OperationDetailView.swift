//
//  OperationDetailView.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct OperationDetailView: View {
    @Environment(AppModel.self) private var appModel
    var context: OperationContext {
        guard let context = appModel.currentOperationContext else {
            return OperationContext(
                operation: OperationDisplayModel.MockData,
                patient: PatientDisplayModel.MockData
            )
        }
        return context
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DetailHeader(operation: context.operation, onClose: {})
                .padding(.horizontal, 32)
                .padding(.top, 32)

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // 모델 이미지
                    AssetSection()

                    // 수술 상세 정보
                    DetailSubPart(
                        title: "수술 상세",
                        content: context.operation.details
                    )

                    // 환자 정보
                    DetailSubPart(
                        title: "환자 정보",
                        content: "\(context.patient.name) (\(context.patient.gender) / \(context.patient.ageText))"
                    )

                    // 집도의 정보
                    DetailSubPart(
                        title: "집도의",
                        content: context.operation.surgeon
                    )

                    // 수술 부위 정보
                    DetailSubPart(
                        title: "수술 부위",
                        content: "여기 수정해야함"
                    )

                    // 진단(병명) 정보
                    DetailSubPart(
                        title: "진단(병명)",
                        content: context.operation.diagnosis
                    )

                    // 수술 날짜 정보
                    DetailSubPart(
                        title: "수술 날짜",
                        content: context.operation.dateText
                    )
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
    }
}

#Preview {
    OperationDetailView()
}
