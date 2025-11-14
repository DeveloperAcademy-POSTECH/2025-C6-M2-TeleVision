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
                            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                        }
                    } header: {
                        HStack {
                            Text("Scheduled Surgery")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    }
                    
                    Spacer()
                    
                    // 완료 수술 섹션
                    Section {
                        ForEach(finished) { sample in
                            OperationCardView(
                                operation: sample,
                                onEdit: onEdit,
                                onDelete: onDelete
                            )
                            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                        }
                    } header: {
                        HStack {
                            Text("Completed Surgery")
                                .font(.headline)
                                .foregroundColor(.gray)
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
