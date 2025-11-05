//
//  TodaysSurgeryView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

struct TodaysSurgeryView: View {
    var mockData = HomeMockDataModel.mockList
    var todaysOperationSample = OperationMockDataModel.todayOperationSamples
    
    var body: some View {
        OperationListView(operationMockData: todaysOperationSample)
    }
}

#Preview {
    TodaysSurgeryView()
}
