//
//  HomView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/2/25.
//

import SwiftUI

struct HomeView: View {
    var mockData = HomeMockDataModel.mockList
    @Binding var isTodaysSurgery: Bool
    
    var body: some View {
        NavigationSplitView {
            //오늘의 수술 버튼
            Button {
                isTodaysSurgery = true
            } label: {
                Text("Today's Surgery")
            }
            List {
                //Patient List 타이틀 위해서 section 추가
                Section {
                    //TODO: 환자 리스트에 데이터가 없는 경우
                    //환자 리스트에 데이터가 있는 경우

                    ForEach(mockData) { data in
                        Button {
                            isTodaysSurgery = false
                        } label: {
                            Text(data.patientNumber)
                            Text(data.name)
                            Text(data.gender)
                            Text("\(data.age)세")
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
