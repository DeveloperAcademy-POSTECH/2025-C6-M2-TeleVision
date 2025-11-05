//
//  PatientDetailView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

struct PatientDetailView: View {
    var mockData = HomeMockDataModel.mockList
    var patientOperationSample = OperationMockDataModel.patientOperationSamples
    
    let patientId: HomeMockDataModel.ID
    private var selectedPatient: HomeMockDataModel? { mockData.first { $0.id == patientId } }
    
    var body: some View {
        OperationListView(operationMockData: patientOperationSample)
            .navigationTitle(selectedPatient.map { "\($0.name) \($0.gender) \($0.age)세" } ?? "환자 상세 정보")
            .navigationSubtitle(selectedPatient?.patientNumber ?? "환자 번호")
    }
}

#Preview {
    RootView()
}
