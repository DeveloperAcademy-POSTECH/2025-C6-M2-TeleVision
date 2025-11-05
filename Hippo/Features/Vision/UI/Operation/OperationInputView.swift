//
//  OperationInputView.swift
//  HippoVision
//
//  Created by 김현기 on 10/30/25.
//

import SwiftUI

enum OperationInputMode: Equatable {
    case create
    case edit(operationID: String)
}

struct OperationInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var appModel
    @State private var viewModel = OperationViewModel()

    let mode: OperationInputMode
    let patientID: String

    init(mode: OperationInputMode, patientID: String) {
        self.mode = mode
        self.patientID = patientID

        switch mode {
        case .create:
            _viewModel = State(initialValue: OperationViewModel())
        case let .edit(operationID):
            _viewModel = State(initialValue: OperationViewModel(patientID: patientID, operationID: operationID))
        }
    }

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
                    selectedAssets: $viewModel.operation3DAssets,
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
            if mode == .create {
                OrnamentButton {
                    Task {
                        await viewModel.addOperation(toPatientID: patientID)
                        appModel.refreshUI()
                        dismiss()
                    }
                }
                .systemName("square.and.arrow.down")
                .content("저장하기")
            } else {
                OrnamentButton {
                    Task {
                        await viewModel.updateOperation()
                        appModel.operationsUpdateTrigger += 1
                        dismiss()
                    }
                }
                .systemName("square.and.arrow.down")
                .content("수정하기")
            }
        }
    }
}

#Preview {
    OperationInputView(mode: .create, patientID: "patient123")
}
