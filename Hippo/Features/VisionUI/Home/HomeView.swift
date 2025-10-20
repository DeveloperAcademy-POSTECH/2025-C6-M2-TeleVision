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

    /// 오늘 예정된 환자 목록 (Computed Property)
    private var todayPlannedPatients: [PatientDisplayModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return viewModel.state.items.filter { patient in
            guard let operation = patient.lastestOperation else { return false }
            let operationDay = calendar.startOfDay(for: operation.date)
            return today == operationDay
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LogoHeader()
                    .padding(.horizontal, 40)
                    .padding(.vertical, 28)

                Divider()

                TodaySectionView(patients: todayPlannedPatients)
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
                    Task {
                        let tempPatientID = String(format: "%08d", Int.random(in: 0 ... 99_999_999))

                        await viewModel.create(
                            patientNumber: tempPatientID,
                            name: "이윤서",
                            gender: .female,
                            birthDate: Calendar.current.date(byAdding: .year, value: -30, to: Date())!
                        )

                        await viewModel.addOperation(
                            toPatientID: viewModel.state.items.first!.id,
                            title: "Laparoscopis LLS TEST  sdfsdffdsefesfse",
                            diagnosis: "간암 / 뇌수술",
                            surgeon: "오남기",
                            date: Calendar.current.date(byAdding: .day, value: 0, to: Date())!,
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
