//
//  TodayOperationScrollView.swift
//  Hippo
//
//  Created by 김현기 on 11/2/25.
//

import SwiftUI

/// 오늘 수술 카드 스크롤뷰
struct TodayOperationScrollView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    let operations: [(patient: PatientDisplayModel, operation: OperationDisplayModel)]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(operations, id: \.operation.id) { item in
                    TodayOperationCard(
                        patient: item.patient,
                        operation: item.operation
                    ) {
                        let context = OperationContext(
                            patientID: item.patient.id,
                            operationID: item.operation.id
                        )
                        appModel.openOperationDetail(
                            context: context,
                            openWindow: openWindow,
                            dismissWindow: dismissWindow
                        )
                    }
                }
            }
        }
    }
}
