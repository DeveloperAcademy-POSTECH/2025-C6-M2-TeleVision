//
//  TodaySectionView.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 오늘 예정된 수술 섹션
struct TodaySectionView: View {
    let operations: [(patient: PatientDisplayModel, operation: OperationDisplayModel)]

    var body: some View {
        if !operations.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader("Today Surgery", subtitle: Date().toTodayDateString())

                TodayOperationScrollView(operations: operations)
            }
            .padding(.top, 20)
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    TodaySectionView(operations: [])
}
