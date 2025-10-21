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

    /// 오늘 예정된 환자 목록 (시간순 정렬, 완료된 수술은 뒤로)
    private var todayPlannedPatients: [PatientDisplayModel] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return viewModel.state.items
            .filter { patient in
                guard let operation = patient.lastestOperation else { return false }
                let operationDay = calendar.startOfDay(for: operation.date)
                return today == operationDay
            }
            .sorted { patient1, patient2 in
                guard let op1 = patient1.lastestOperation,
                      let op2 = patient2.lastestOperation
                else {
                    return false
                }

                // 1. 완료된 수술은 뒤로
                if op1.status == .completed && op2.status != .completed {
                    return false
                }
                if op1.status != .completed && op2.status == .completed {
                    return true
                }

                // 2. 같은 상태면 수술 시간 오름차순 (이른 시간이 먼저)
                return op1.date < op2.date
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
