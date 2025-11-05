//
//  PatientInputView.swift
//  HippoVision
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

enum PatientInputMode: Equatable {
    case create
    case edit
}

struct PatientInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @Environment(HomeViewModel.self) private var viewModel

    let mode: PatientInputMode

    init(mode: PatientInputMode = .create) {
        self.mode = mode
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if viewModel.state.isLoading {
                    ProgressView("환자 정보 로딩 중...")
                } else {
                    contentView
                }
            }
        }
        .padding(.horizontal, 28)
        .frame(width: 460, height: 680)
        .glassBackgroundEffect(displayMode: .always)
        .task {
            if case .edit = mode {
                await viewModel.loadPatientInfoToInputView()
            }
        }
        .ornament(attachmentAnchor: .parent(.bottom)) {
            OrnamentButton {
                viewModel.handleSubmit(mode: mode)
                appModel.refreshUI()
                dismiss()
            }
            .systemName("square.and.arrow.down")
            .content(mode == .create ? "추가하기" : "수정하기")
        }
        .alert("작성을 취소할까요?", isPresented: $viewModel.isShowDismissAlert) {
            Button("네", role: .destructive) {
                dismiss()
            }
            Button("아니요", role: .cancel) { viewModel.isShowDismissAlert = false }
        } message: {
            Text("지금까지 입력한 내용이\n모두 사라집니다")
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentView: some View {
        @Bindable var viewModel = viewModel
        
        VStack(spacing: 0) {
            PatientInputHeader(onDismiss: {
                viewModel.isShowDismissAlert = true
            })

            Spacer().frame(height: 56)

            PatientInputForm(
                patientNumber: $viewModel.patientNumber,
                name: $viewModel.name,
                birthDate: $viewModel.birthDate,
                selectedGender: $viewModel.selectedGender
            )

            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(width: 460, height: 680)
        .glassBackgroundEffect(displayMode: .always)
        .ornament(attachmentAnchor: .parent(.bottom)) {
            OrnamentButton {
                handleSubmit()
            }
            .systemName("square.and.arrow.down")
            .content(mode == .create ? "추가하기" : "수정하기")
        }
        .alert("작성을 취소할까요?", isPresented: $viewModel.isShowDismissAlert) {
            Button("네", role: .destructive) { dismiss() }
            Button("아니요", role: .cancel) { viewModel.isShowDismissAlert = false }
        } message: {
            Text("지금까지 입력한 내용이\n모두 사라집니다")
        }
        .task {
            if case let .edit(patientID) = mode {
                await loadPatientData(patientID: patientID)
            }
        }
    }

    private func loadPatientData(patientID: String) async {
        // getPatient dependency를 사용하여 환자 데이터 로드
        do {
            let patient = try await viewModel.getPatient.run(patientID)
            let displayModel = patient.toDisplayModel()

            // ViewModel에 데이터 설정
            viewModel.patientNumber = displayModel.patientNumber
            viewModel.name = displayModel.name
            viewModel.selectedGender = Gender.from(string: displayModel.gender)
            viewModel.birthDate = Date.fromTodayDateString(displayModel.birthDateText) ?? Date()
        } catch {
            // 에러 처리 - 필요시 alert 표시
            print("Failed to load patient data: \(error)")
        }
    }
}

    private func handleSubmit() {
        Task {
            switch mode {
            case .create:
                await viewModel.create(
                    patientNumber: viewModel.patientNumber,
                    name: viewModel.name,
                    gender: viewModel.selectedGender,
                    birthDate: viewModel.birthDate
                )
                appModel.patients += 1
            case let .edit(patientID):
                await viewModel.update(
                    patientID: patientID,
                    patientNumber: viewModel.patientNumber,
                    name: viewModel.name,
                    gender: viewModel.selectedGender,
                    birthDate: viewModel.birthDate
                )
                appModel.patientsUpdateTrigger += 1
            }
            dismiss()
        }
    }
}

#Preview {
    PatientInputView(mode: .create)
}
