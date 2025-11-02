//
//  HomeView.swift
//  HippoVision
//
//  Created by 김현기 on 10/18/25.
//

import SwiftUI

/// 환자 목록 메인 화면 - 컨테이너 역할
struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    
    // 테스트용
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace

    @State private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LogoHeader()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)

                Divider()

                TodaySectionView(operations: viewModel.todayOperations)
                    .padding(.top, 20)
                    .padding(.horizontal, 40)

                PatientSectionView(patients: viewModel.state.items)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .task {
            await viewModel.load()
            appModel.patients = viewModel.state.items.count
        }
        .onChange(of: appModel.patients) {
            Task {
                await viewModel.load()
            }
        }
        .onChange(of: appModel.operations) {
            Task {
                await viewModel.load()
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            OrnamentButton {
                viewModel.isPresentingCreatePatientSheet = true
            }
        }
        .sheet(isPresented: $viewModel.isPresentingCreatePatientSheet) {
            PatientInputView()
        }
    }
}

#Preview {
    HomeView()
}
