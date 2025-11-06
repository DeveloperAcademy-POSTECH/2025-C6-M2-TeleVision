//
//  OperationListView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct OperationListView: View {
    // PatientDetailView에서 전달받을 데이터
    let operations: [OperationDisplayModel]
    let onDelete: (String) async -> Void

    var body: some View {
        Text("입력된 수술이 없습니다.")
        //TODO: 리스트 뷰 or 스크롤 뷰 선택
        //TODO: 수술 디테일 카드뷰 추가
    }
}

#Preview {
    OperationListView(
        operations: [],
        onDelete: { _ in }
    )
}
