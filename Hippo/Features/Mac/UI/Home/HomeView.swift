//
//  HomView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/2/25.
//

import SwiftUI

struct HomeView: View {
    // ViewModel 초기화
    @State private var rootVM = MacRootViewModel()
    
    // Mock 데이터 (UI 개발용 - 나중에 rootVM.homeViewModel.state.items로 교체)
//    var mockData = HomeMockDataModel.mockList
//    @State private var selectedPatientID: HomeMockDataModel.ID?
//    private var selectedPatient: HomeMockDataModel? { mockData.first { $0.id == selectedPatientID } }
    
    var body: some View {
        
        NavigationSplitView {
            //오늘의 수술 버튼
            Button {
                rootVM.selectTodaysSurgery()
            } label: {
                Text("Today's Surgery")
            }
            List {
                //Patient List 타이틀 위해서 section 추가함
                Section {
                    //TODO: 환자 리스트에 데이터가 없는 경우
                    
                    //환자 리스트에 데이터가 있는 경우
                    ForEach(rootVM.loadedPatients, id: \.id) { data in
                        HStack {
                            Button {
                                rootVM.selectPatient(data.id)
                            } label: {
                                Text(data.patientNumber)
                                Text(data.name)
                                Text(data.genderText)
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
                            rootVM.openPatientCreateSheet()
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                    }
                }
            }
        } detail: {
            if rootVM.isTodaysSurgerySelected {
                TodaysSurgeryView(viewModel: rootVM.homeViewModel)
                    .navigationTitle("Today's Surgery")
            } else {
                PatientDetailView(
                    viewModel: PatientDetailViewModel(rootVM: rootVM),
                    selectedPatient: rootVM.selectedPatient,
                    isTodaysSurgerySelected: rootVM.isTodaysSurgerySelected
                )
            }
        }
        .toolbar {
            if !rootVM.isTodaysSurgerySelected {
                Button {
                    //TODO: 수술 생성 기능 구현
                    rootVM.openOperationCreateSheet()
                } label: {
                    Label("Create", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $rootVM.navigationState.isPresentingPatientInput) {
            PatientInputView(
                isPresentingPatientInput: $rootVM.navigationState.isPresentingPatientInput,
                state: $rootVM.patientInputState,
                mode: rootVM.navigationState.patientInputMode,
                onSave: {
                    Task {
                        if rootVM.navigationState.patientInputMode == .create {
                            await rootVM.createPatient()
                        } else {
                            await rootVM.updatePatient()
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $rootVM.navigationState.isPresentingOperationInput) {
            OperationInputView(
                isPresentingOperationInput: $rootVM.navigationState.isPresentingOperationInput,
                state: $rootVM.operationInputState,
                onSave: {
                    Task {
                        await rootVM.createOperation()
                    }
                }
            )
        }
        .task {
            // 데이터 로드 (비어 있으면 목업 주입 후 실제 로드)
            await rootVM.load()
            
            // 목업 데이터 주입
            if rootVM.homeViewModel.state.items.isEmpty {
                rootVM.homeViewModel.state.items = [
                    PatientDisplayModel.MockData,
                ]
            }
          
        }
    }
}

#Preview {
    RootView()
}

