//
//  HomView.swift
//  HippoMac
//
//  Created by Hyeok Cho on 11/2/25.
//

import Dependencies
import SwiftUI

struct HomeView: View {
    // ViewModel 초기화
    @State private var rootVM = MacRootViewModel()
    @Dependency(\.syncMonitor) var syncMonitor

    @State private var hoveredPatientID: String? = nil

    var body: some View {
        NavigationSplitView {
            HomeViewSideBar(rootVM: $rootVM, hoveredPatientID: $hoveredPatientID)
                .background(Color.white)
        } detail: {
            if rootVM.isTodaysSurgerySelected {
                TodaysSurgeryView(
                    viewModel: TodaysSurgeryViewModel(rootVM: rootVM)
                )
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
                // 수술 생성 버튼
                Button {
                    rootVM.openOperationCreateSheet()
                } label: {
                    Label("Create", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $rootVM.navigationState.isPresentingPatientInput) {
            PatientInputView(
                isPresentingPatientInput: $rootVM.navigationState
                    .isPresentingPatientInput,
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
                isPresentingOperationInput: $rootVM.navigationState
                    .isPresentingOperationInput,
                state: $rootVM.operationInputState,
                mode: rootVM.navigationState.operationInputMode,
                onSave: {
                    Task {
                        if rootVM.navigationState.operationInputMode == .create {
                            await rootVM.createOperation()
                        } else {
                            await rootVM.updateOperation()
                        }
                    }
                }
            )
        }
        .task {
            // 데이터 로드
            await rootVM.load()
        }
        .onChange(of: syncMonitor.dataDidChange) {
            if syncMonitor.dataDidChange {
                Task {
                    await rootVM.load()
                    syncMonitor.resetDataChangeFlag()
                }
            }
        }
    }
}

#Preview {
    RootView()
}
