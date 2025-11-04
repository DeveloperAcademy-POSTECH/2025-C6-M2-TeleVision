//
//  PatientDetailView.swift
//  HippoVision
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct PatientDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = PatientViewModel()

    let patientId: String

    var body: some View {
        Group {
            if viewModel.state.isLoading {
                ProgressView()
            } else if let patient = viewModel.state.patient {
                contentView(patient: patient)
            } else {
                ContentUnavailableView(
                    "환자 정보를 찾을 수 없습니다",
                    systemImage: "person.slash"
                )
            }
        }
        .environment(viewModel)
        .frame(minWidth: 580, maxWidth: 580, minHeight: 800, maxHeight: 1080)
        .glassBackgroundEffect(displayMode: .always)
        .task {
            await viewModel.load(patientID: patientId)
            if let patient = viewModel.state.patient {
                appModel.operations = patient.operationCount
            }
        }
        .onChange(of: appModel.operations) {
            Task {
                await viewModel.load(patientID: patientId)
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            if !viewModel.isPresentingOperationInput && !viewModel.isShowingEditSheet {
                OrnamentButton {
                    viewModel.isPresentingOperationInput = true
                }
                .systemName("long.text.page.and.pencil")
                .content("수술 추가")
            }
        }
        .sheet(isPresented: $viewModel.isPresentingOperationInput) {
            OperationInputView(mode: .create, patientID: patientId)
        }
        .sheet(isPresented: $viewModel.isShowingEditSheet) {
            PatientInputView()
        }
    }

    // MARK: - Subviews

    private func contentView(patient: PatientDisplayModel) -> some View {
        VStack {
            PatientDetailHeader(
                name: patient.name,
                gender: patient.gender,
                ageText: patient.ageText,
                number: patient.patientNumber,
                onDismiss: { dismiss() }
            )

            Spacer()

            if patient.operationCount != 0 {
                OperationList(
                    patientID: patientId,
                    operations: patient.operations
                )
            } else {
                EmptyOperationView()
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private func errorView(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)

            Text("환자 정보를 불러올 수 없습니다")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("다시 시도") {
                Task {
                    await viewModel.load(patientID: patientId)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    PatientDetailView(patientId: "sample-001")
}
