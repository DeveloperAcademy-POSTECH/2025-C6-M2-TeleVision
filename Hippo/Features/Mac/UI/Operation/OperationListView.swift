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
            Text("예정된 수술이 없습니다.")
                .foregroundStyle(.hippoGray500)
                .font(.title2)
                .fontWeight(.bold)
                .padding()
        } else {
            // 오늘을 기준으로 수술 카드 나누기
            let upcoming =
                operations // TODO: 실제 데이터 배열과 연결하기
                .filter { $0.status == .planned }
                .sorted { $0.operationDate < $1.operationDate }
            let finished =
                operations // TODO: 실제 데이터 배열과 연결하기
                .filter { $0.status != .planned }
                .sorted { $0.operationDate > $1.operationDate }

            ScrollView {
                LazyVStack {
                    Spacer().frame(height: 12)
                    
                    HStack {
                        Text("오늘의 수술")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.hippoGray500)
                        
                        Spacer()
                    }
                    
                    Spacer().frame(height: 24)

                    if !upcoming.isEmpty {
                        Section {
                            ForEach(upcoming) { operation in
                                OperationCardView(
                                    operation: operation,
                                    onEdit: onEdit,
                                    onDelete: onDelete
                                )
                                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                            }
                        } header: {
                            HStack {
                                Text("대기중인 수술")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.hippoGray500)
                                Spacer()
                            }
                        }

                        Spacer()
                    }

                    if !finished.isEmpty {
                        // 완료 수술 섹션
                        Section {
                            ForEach(finished) { operation in
                                OperationCardView(
                                    operation: operation,
                                    onEdit: onEdit,
                                    onDelete: onDelete
                                )
                                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
                            }
                        } header: {
                            HStack {
                                Text("완료된 수술")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.hippoGray500)
                                Spacer()
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }
}

// #Preview {
//    OperationListView(operationMockData:)
// }
