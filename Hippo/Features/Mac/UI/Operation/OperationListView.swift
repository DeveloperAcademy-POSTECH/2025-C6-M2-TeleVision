//
//  OperationListView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct OperationListView: View {
    private var operationMockData = OperationMockDataModel.samples
    
    var body: some View {
        if operationMockData.isEmpty {
            Text("입력된 수술이 없습니다.")
        } else {
            //TODO: 리스트 뷰 or 스크롤 뷰 선택
            //TODO: 수술 디테일 카드뷰 추가
            ScrollView {
                ForEach (OperationMockDataModel.samples) { samples in
                    OperationCardView()
                }
            }
        }
    }
}

#Preview {
    OperationListView()
}
