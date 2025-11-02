//
//  PatientInputView.swift
//  HippoVision
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct PatientInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = HomeViewModel()

    var body: some View {
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
            .content("추가하기")
        }
        .alert("작성을 취소할까요?", isPresented: $viewModel.isShowDismissAlert) {
            Button("네", role: .destructive) { dismiss() }
            Button("아니요", role: .cancel) { viewModel.isShowDismissAlert = false }
        } message: {
            Text("지금까지 입력한 내용이\n모두 사라집니다")
        }
    }

    private func handleSubmit() {
        Task {
            await viewModel.create(
                patientNumber: viewModel.patientNumber,
                name: viewModel.name,
                gender: viewModel.selectedGender,
                birthDate: viewModel.birthDate
            )
            appModel.patients += 1
            dismiss()
        }
    }
}

#Preview {
    PatientInputView()
}
