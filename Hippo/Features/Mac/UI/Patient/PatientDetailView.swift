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
<<<<<<< HEAD
    var patientOperationSample = OperationMockDataModel.patientOperationSamples
    
=======
    let patientId: HomeMockDataModel.ID
>>>>>>> develop
    private var selectedPatient: HomeMockDataModel? { mockData.first { $0.id == patientId } }
    
    let patientId: HomeMockDataModel.ID
    
    var isTodaysSurgery: Bool
    
    var body: some View {
<<<<<<< HEAD
        OperationListView(operationMockData: patientOperationSample)
            .navigationTitle(selectedPatient.map { "\($0.name) \($0.gender) \($0.age)세" } ?? "환자 상세 정보")
            .navigationSubtitle(selectedPatient?.patientNumber ?? "환자 번호")
=======
        OperationListView(
            operations: viewModel.operations,
            onDelete: { operationID in
                Task {
                    await viewModel.deleteOperation(operationID)
                }
            }
        )
        .navigationTitle(selectedPatient.map { "\($0.name) \($0.gender) \($0.age)세" } ?? "환자 상세 정보")
        .navigationSubtitle(selectedPatient?.patientNumber ?? "환자 번호")
>>>>>>> develop
    }
}

#Preview {
    let rootVM = MacRootViewModel()
    PatientDetailView(
        viewModel: PatientDetailViewModel(rootVM: rootVM),
        patientId: ""
    )
}
