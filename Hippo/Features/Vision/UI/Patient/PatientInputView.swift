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
            PatientInputHeader(onDismiss: { dismiss() })

            Spacer().frame(height: 56)

            PatientInputForm(
                patientNumber: $viewModel.patientNumber,
                name: $viewModel.name,
                birthDate: $viewModel.birthDate,
                selectedGender: $viewModel.selectedGender
            )

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(width: 512, height: 700)
        .glassBackgroundEffect(displayMode: .always)
        .ornament(attachmentAnchor: .scene(.bottom)) {
            OrnamentButton {
                handleSubmit()
            }
            .systemName("square.and.arrow.down")
            .content("추가하기")
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
