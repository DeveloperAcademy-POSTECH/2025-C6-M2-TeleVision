//
//  TodaysSurgeryView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

struct TodaysSurgeryView: View {
    // HomeView의 homeViewModel 전달받기 (todayOperations 사용)
    let viewModel: HomeViewModel

    var body: some View {
        Text("오늘의 수술이 없습니다.")
    }
}

#Preview {
    TodaysSurgeryView(viewModel: HomeViewModel())
}
