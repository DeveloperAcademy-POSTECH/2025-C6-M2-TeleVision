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
        ZStack {
            switch viewModel.loadingState {
            case .idle, .loading:
                loadingView
            case let .loaded(patient):
                contentView(patient: patient)
            case let .error(error):
                errorView(error: error)
            }
        }
        .frame(minWidth: 580, maxWidth: 580, minHeight: 800, maxHeight: 1080)
        .glassBackgroundEffect(displayMode: .always)
        .task {
            await viewModel.load(patientID: patientId)
            if let patient = viewModel.patient {
                appModel.operations = patient.operationCount
            }
        }
        .onChange(of: appModel.operations) {
            Task {
                await viewModel.load(patientID: patientId)
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            if !viewModel.isPresentingOperationInput {
                OrnamentButton {
                    viewModel.isPresentingOperationInput = true
                }
                .systemName("long.text.page.and.pencil")
                .content("수술 추가")
            }
        }
        .sheet(isPresented: $viewModel.isPresentingOperationInput) {
            OperationInputView(patientID: patientId)
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack {
            ProgressView()
                .controlSize(.large)
            Text("환자 정보를 불러오는 중...")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.top)
        }
    }

    private func contentView(patient: PatientDisplayModel) -> some View {
        VStack {
            PatientDetailHeader(
                name: patient.name,
                gender: patient.gender,
                ageText: patient.ageText,
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
