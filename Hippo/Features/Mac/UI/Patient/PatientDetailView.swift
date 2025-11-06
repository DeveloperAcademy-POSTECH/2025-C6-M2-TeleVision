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

    // Mock 데이터 (UI 개발용)
    var mockData = HomeMockDataModel.mockList

    private var selectedPatient: HomeMockDataModel? { mockData.first { $0.id == patientId } }
    
    let patientId: HomeMockDataModel.ID
    
    var isTodaysSurgery: Bool
    
    var body: some View {

        OperationListView(
            operations: viewModel.operations,
            onDelete: { operationID in
//                Task {
//                    await viewModel.deleteOperation(operationID)
//                }
                //TODO: 원띵과 논의 필요
            }
        )
        .navigationTitle(selectedPatient.map { "\($0.name) \($0.gender) \($0.age)세" } ?? "환자 상세 정보")
        .navigationSubtitle(selectedPatient?.patientNumber ?? "환자 번호")
    }
}

#Preview {
    @Previewable @State var isTodaysSurgery: Bool = false
    
    let rootVM = MacRootViewModel()
    PatientDetailView(
        viewModel: PatientDetailViewModel(rootVM: rootVM),
        patientId: "",
        isTodaysSurgery: isTodaysSurgery
    )
}
