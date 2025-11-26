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
            VStack {
                HStack {
                    if rootVM.isTodaysSurgerySelected {
                        Text("오늘의 수술")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.hippoGray700)
                    } else {
                        if let patient = rootVM.selectedPatient {
                            VStack(alignment: .leading) {
                                Text("\(patient.name) 환자 (\(patient.genderText) / \(patient.age)세)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.hippoGray700)
                                Text(patient.patientNumber)
                                    .font(.headline)
                                    .foregroundStyle(.hippoGray300)
                            }
                            .padding(.trailing, 16)

                            Button {
                                rootVM.openOperationCreateSheet()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(.hippoPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()
                }
                .frame(height: 32)
                .padding(.top, 28)
                .padding(.horizontal)
                .padding(.bottom)

                Spacer()

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

                Spacer()
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
