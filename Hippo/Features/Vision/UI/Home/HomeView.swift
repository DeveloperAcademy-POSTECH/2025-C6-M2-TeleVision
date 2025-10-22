//
//  HomeView.swift
//  HippoVision
//
//  Created by 김현기 on 10/18/25.
//

import SwiftUI

/// 환자 목록 메인 화면 - 컨테이너 역할
struct HomeView: View {
    @State private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LogoHeader()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)

                Divider()

                TodaySectionView(patients: viewModel.todayPlannedPatients)
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
        }
        .toolbar {
            ToolbarItem(placement: .bottomOrnament) {
                AddPatientButton {
                    // FIXME: - 추후 삭제 후 실제 로직 반영 필요
                    Task {
                        let tempPatientID = String(format: "%08d", Int.random(in: 0 ... 99_999_999))

                        await viewModel.create(
                            patientNumber: tempPatientID,
                            name: "김선환",
                            gender: .female,
                            birthDate: Calendar.current.date(byAdding: .year, value: -30, to: Date())!
                        )

                        await viewModel.addOperation(
                            toPatientID: viewModel.state.items.first!.id,
                            title: "Laparoscopis LLS TEST  sdfsdffdsefesfse",
                            diagnosis: "간암 / 뇌수술",
                            surgeon: "오남기",
                            date: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!,
                            status: .completed
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
