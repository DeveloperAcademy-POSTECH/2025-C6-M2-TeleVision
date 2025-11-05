//
//  HomView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/2/25.
//

import SwiftUI

struct HomeView: View {
    var mockData = HomeMockDataModel.mockList
    @State private var isTodaysSurgery: Bool = true
    @State private var selectedPatientID: HomeMockDataModel.ID?
    private var selectedPatient: HomeMockDataModel? { mockData.first { $0.id == selectedPatientID } }
    @State var isPatientInputSheetPresented: Bool = false
    @State var isOperationInputSheetPresented: Bool = false
    
    var body: some View {
        NavigationSplitView {
            //오늘의 수술 버튼
            Button {
                isTodaysSurgery = true
                selectedPatientID = nil
            } label: {
                Text("Today's Surgery")
            }
            List {
                //Patient List 타이틀 위해서 section 추가함
                Section {
                    //TODO: 환자 리스트에 데이터가 없는 경우
                    //환자 리스트에 데이터가 있는 경우

                    ForEach(mockData) { data in
                        HStack {
                            Button {
                                isTodaysSurgery = false
                                selectedPatientID = data.id
                            } label: {
                                Text(data.patientNumber)
                                Text(data.name)
                                Text(data.gender)
                                Text("\(data.age)세")
                            }
                            //TODO: 호버 시 편집 버튼 띄우기 추가
                        }
                    }
                } header: {
                    HStack {
                        //헤더 텍스트
                        Text("Patient List")
                        Spacer()
                    
                        //환자 추가 버튼
                        Button {
                            //TODO: PatientInputView 구현
                            isPatientInputSheetPresented = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
        } detail: {
            if isTodaysSurgery {
                TodaysSurgeryView()
                    .navigationTitle("Today's Surgery")
            } else {
                PatientDetailView(patientId: selectedPatientID ?? "")
            }
        }
        .toolbar {
            if !isTodaysSurgery {
                Button {
                    //TODO: 수술 생성 기능 구현
                    isOperationInputSheetPresented = true
                } label: {
                    Label("Create", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isPatientInputSheetPresented) {
            PatientInputView(isPatientInputSheetPresented: $isPatientInputSheetPresented)
        }
        .sheet(isPresented: $isOperationInputSheetPresented) {
            OperationInputView(isOperationInputSheetPresented: $isOperationInputSheetPresented)
        }
    }
}

#Preview {
    RootView()
}
