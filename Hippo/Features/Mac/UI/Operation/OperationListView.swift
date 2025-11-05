//
//  OperationListView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/4/25.
//

import SwiftUI

struct OperationListView: View {//TODO: 실제 데이터 연결 시에는 환자정보도 같이 가져와야 할 듯?
    var operationMockData: [OperationMockDataModel]
    @State var now = Date()
    
    
    var body: some View {
        if operationMockData.isEmpty {
            Text("입력된 수술이 없습니다.")
                .padding()
        } else {
            // 오늘을 기준으로 수술 데이터 나누기
            let upcoming = operationMockData //TODO: 실제 데이터 배열과 연결하기
                .filter { $0.date > now }
                .sorted { $0.date < $1.date }
            let finished = operationMockData //TODO: 실제 데이터 배열과 연결하기
                .filter { $0.date <= now }
                .sorted { $0.date > $1.date }
            
            // TODO: 리스트 뷰 or 스크롤 뷰 선택
            // TODO: 수술 디테일 카드뷰 추가

            ScrollView {
                LazyVStack() {
                    
                    // 대기 수술 섹션
                    Section {
                        ForEach(upcoming) { sample in
                            OperationCardView()
                        }
                    } header: {
                        HStack {
                            Text("대기 수술")
                            Spacer()
                        }
                    }

                    // 완료 수술 섹션
                    Section {
                        ForEach(finished) { sample in
                            OperationCardView()
                        }
                    } header: {
                        HStack {
                            Text("완료 수술")
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
//    OperationListView()
//}
