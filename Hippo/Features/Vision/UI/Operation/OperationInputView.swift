//
//  OperationInputView.swift
//  HippoVision
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

struct OperationInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = OperationViewModel()

    let patientID: String

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OperationInputHeader(onDismiss: { dismiss() })

                Spacer().frame(height: 56)

                OperationInputForm(
                    title: $viewModel.operationTitle,
                    diagnosis: $viewModel.operationDiagnosis,
                    surgeon: $viewModel.operationSurgeon,
                    operationDate: $viewModel.operationDate,
                    detail: $viewModel.operationDetail,
                    selected3DFiles: $viewModel.operation3DFileURLs,
                    isShowingFilePicker: $viewModel.isShowingFilePicker
                )
                .padding(.bottom, 32)

                Spacer()
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 32)
        .frame(width: 460, height: 680)
        .glassBackgroundEffect(displayMode: .always)
        .ornament(attachmentAnchor: .parent(.bottom)) {
            OrnamentButton {
                // 수술 저장하기
                Task {
                    await viewModel.addOperation(toPatientID: patientID)
                    appModel.operations += 1
                    dismiss()
                }
            }
            .systemName("square.and.arrow.down")
            .content("저장하기")
        }
    }
}

#Preview {
    OperationInputView(patientID: "")
}
