//
//  PatientDetailView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

struct PatientDetailView: View {
    // ViewModel 초기화 (HomeView에서 rootVM 전달받음)
    let viewModel: PatientDetailViewModel

    var selectedPatient: PatientDisplayModel?

    var isTodaysSurgerySelected: Bool

    var body: some View {

        OperationListView(
            operations: viewModel.operationCards,
            onEdit: { operationID in
                viewModel.selectedOperationID = operationID
                //수술 수정 시트 열기
                if let op = viewModel.operation(by: operationID) {
                    viewModel.openOperationEditSheet(operation: op)
                }
            },
            onDelete: { operationID in
                Task {
                    await viewModel.deleteOperation(operationID)
                }
            }
        )
        .navigationTitle(
            selectedPatient.map { "\($0.name) \($0.gender) Age\($0.age)" }
                ?? "환자 상세 정보"
        )
        .navigationSubtitle(selectedPatient?.patientNumber ?? "Patient Number")
    }
}

#Preview {
    @Previewable @State var isTodaysSurgery: Bool = false

    let rootVM = MacRootViewModel()
    PatientDetailView(
        viewModel: PatientDetailViewModel(rootVM: rootVM),
        isTodaysSurgerySelected: isTodaysSurgery
    )
}

