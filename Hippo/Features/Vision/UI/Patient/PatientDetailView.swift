//
//  PatientDetailView.swift
//  HippoVision
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct PatientDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = PatientViewModel()

    let patientId: String

    private var patient: PatientDisplayModel {
        viewModel.patient ?? PatientDisplayModel.MockData
    }

    var body: some View {
        VStack {
            PatientDetailHeader(
                name: patient.name,
                gender: patient.gender,
                ageText: patient.ageText,
                onDismiss: { dismiss() }
            )

            Spacer()

            if patient.operationCount != 0 {
                OperationList(operations: patient.operations)
            } else {
                EmptyOperationView()
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(minWidth: 580, maxWidth: 580, minHeight: 800, maxHeight: 1080)
        .glassBackgroundEffect(displayMode: .always)
        .task {
            await viewModel.load(patientID: patientId)
            appModel.operations = viewModel.patient?.operationCount ?? 0
        }
        .onChange(of: appModel.operations) {
            Task {
                await viewModel.load(patientID: patientId)
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            OrnamentButton {
                viewModel.isPresentingOperationInput = true
            }
            .systemName("long.text.page.and.pencil")
            .content("수술 추가")
        }
        .sheet(isPresented: $viewModel.isPresentingOperationInput) {
            OperationInputView(patientID: patientId)
        }
    }
}

#Preview {
    PatientDetailView(patientId: "sample-001")
}
