//
//  HomeView.swift
//  HippoVision
//
//  Created by 김현기 on 10/18/25.
//

import Dependencies
import SwiftUI

/// 환자 목록 메인 화면 - 컨테이너 역할
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(HomeViewModel.self) private var viewModel
    @Dependency(\.syncMonitor) var syncMonitor

    // 테스트용
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    var body: some View {
        @Bindable var viewModel = viewModel

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LogoHeader(
                    syncMonitor: syncMonitor,
                    onRefresh: {
                        syncMonitor.dataDidChange = true
                    }
                )
                .padding(.horizontal, 40)
                .padding(.vertical, 28)

                Divider()

                TodaySectionView(operations: viewModel.todayOperations)

                PatientSectionView(patients: viewModel.state.items)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .task {
            await viewModel.load()
        }
        .onChange(of: appModel.refreshID) {
            Task {
                await viewModel.load()
                if let selectedPatient = viewModel.state.selectedPatient {
                    await viewModel.load(patientID: selectedPatient.id)
                }
            }
        }
        .onChange(of: syncMonitor.dataDidChange) {
            if syncMonitor.dataDidChange {
                Task {
                    await viewModel.load()
                    if let selectedPatient = viewModel.state.selectedPatient {
                        await viewModel.load(patientID: selectedPatient.id)
                    }
                    syncMonitor.resetDataChangeFlag()
                }
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            if !viewModel.isPresentingCreatePatientSheet {
                OrnamentButton {
                    viewModel.isPresentingCreatePatientSheet = true
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingCreatePatientSheet) {
            PatientInputView(mode: .create)
        }
    }
}

#Preview {
    HomeView()
}
