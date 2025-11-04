//
//  PatientDetailView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/3/25.
//

import SwiftUI

struct PatientDetailView: View {
    var mockData = HomeMockDataModel.mockList
    
    var body: some View {
        Text("입력된 수술이 없습니다.")
        //TODO: 리스트 뷰 or 스크롤 뷰 선택
        //TODO: 수술 디테일 카드뷰 추가
    }
}

#Preview {
    PatientDetailView()
}
