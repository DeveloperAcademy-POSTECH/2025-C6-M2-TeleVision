//
//  OperationListView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct OperationListView: View {

    var operations: [OperationCardDisplayModel]
    let onEdit: (String) -> Void
    let onDelete: (String) -> Void

    @State var now = Date()

    var body: some View {
        if operations.isEmpty {
            Text("입력된 수술이 없습니다.")
                .padding()
        } else {
            // 오늘을 기준으로 수술 카드 나누기
            let upcoming =
                operations  //TODO: 실제 데이터 배열과 연결하기
                .filter { $0.operationDate > now }
                .sorted { $0.operationDate < $1.operationDate }
            let finished =
                operations  //TODO: 실제 데이터 배열과 연결하기
                .filter { $0.operationDate <= now }
                .sorted { $0.operationDate > $1.operationDate }

            // TODO: 리스트 뷰 or 스크롤 뷰 선택
            // TODO: 수술 디테일 카드뷰 추가

            ScrollView {
                LazyVStack {

                    // 대기 수술 섹션
                    Section {
                        ForEach(upcoming) { sample in
                            OperationCardView(
                                operation: sample,
                                onEdit: onEdit,
                                onDelete: onDelete
                            )
                        }
                    } header: {
                        HStack {
                            Text("Scheduled Surgery")
                            Spacer()
                        }
                    }

                    // 완료 수술 섹션
                    Section {
                        ForEach(finished) { sample in
                            OperationCardView(
                                operation: sample,
                                onEdit: onEdit,
                                onDelete: onDelete
                            )

                        }
                    } header: {
                        HStack {
                            Text("Completed Surgery")
                            Spacer()
                        }
                    }

                }
                .padding()
            }
        }
    }
}

//#Preview {
//    OperationListView(operationMockData:)
//}
