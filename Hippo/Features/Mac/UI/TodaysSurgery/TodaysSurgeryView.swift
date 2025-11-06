//
//  TodaysSurgeryView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

struct TodaysSurgeryView: View {
<<<<<<< HEAD
    
=======
    // HomeView의 homeViewModel 전달받기 (todayOperations 사용)
    let viewModel: HomeViewModel

>>>>>>> develop
    var body: some View {
        
        // 오늘 날짜(자정 기준) 범위 계산
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        // 오늘에 해당하는 수술만 필터링
        let todaysOperations = OperationMockDataModel.patientOperationSamples
            .filter { $0.date >= startOfToday && $0.date < startOfTomorrow }
            .sorted { $0.date < $1.date }

        return OperationListView(operationMockData: todaysOperations)
    }
}

#Preview {
    TodaysSurgeryView(viewModel: HomeViewModel())
}
