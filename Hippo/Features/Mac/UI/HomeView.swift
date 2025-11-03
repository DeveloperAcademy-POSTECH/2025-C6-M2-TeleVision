//
//  HomView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/2/25.
//

import SwiftUI

struct HomeView: View {
    @State private var isTodaysSurgery = true
    
    var body: some View {
        NavigationSplitView {
            List {
                //오늘의 수술 버튼
                Button {
                    isTodaysSurgery = true
                } label: {
                    Text("Today's Surgery")
                }
                //Patient List 섹션
                    Section {
                        //TODO: 환자 리스트에 데이터가 없는 경우
                        //환자 리스트에 데이터가 있는 경우
                        ForEach(0..<5, id: \.self) { index in
                            Button {
                                isTodaysSurgery = false
                            } label: {
                                Text("환자 \(index)")
                            }
                        }
                    } header: {
                        HStack {
                            Text("Patient List")
                            Spacer()
                            
                            //환자 추가 버튼
                            Button {
                                //TODO: 환자 추가 기능 구현
                            } label: {
                                Image(systemName: "person.badge.plus")
                            }
                        }   
                    }
            }
        } detail: {
            if isTodaysSurgery {
                TodaysSurgeryView()
            } else {
                PatientDetailView()
            }
        }
    }
}

#Preview {
    RootView()
}
