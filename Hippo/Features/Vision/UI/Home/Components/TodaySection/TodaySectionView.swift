//
//  TodaySectionView.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

/// 오늘 예정된 수술 섹션
struct TodaySectionView: View {
    let patients: [PatientDisplayModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader("Today Surgery", subtitle: Date().toTodayDateString())

            if patients.isEmpty {
                EmptyTodaySurgeryView()
            } else {
                TodayOperationScrollView(patients: patients)
            }
        }
    }
}

/// 오늘 수술 없음 표시
private struct EmptyTodaySurgeryView: View {
    var body: some View {
        Text("오늘 예정된 수술이 없습니다")
            .foregroundStyle(.secondary)
            .font(.title2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
    }
}

/// 오늘 수술 카드 스크롤뷰
private struct TodayOperationScrollView: View {
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = HomeViewModel()
    let patients: [PatientDisplayModel]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(patients) { patient in
                    TodayOperationCard(patient: patient) {
                        if let operation = patient.latestOperation {
                            let context = OperationContext(
                                patientID: patient.id,
                                operationID: operation.id
                            )
                            openWindow(id: WindowIDs.operationDetail, value: context)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    TodaySectionView(patients: [])
}
