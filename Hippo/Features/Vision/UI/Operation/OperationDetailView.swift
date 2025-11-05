//
//  OperationDetailView.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct OperationDetailView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow

    let patientID: String
    let operationID: String

    @State private var viewModel = OperationViewModel()
    @State private var isLoaded = false

    var body: some View {
        Group {
            if isLoaded, let operation = viewModel.state.operation, let patient = viewModel.state.patient {
                VStack(alignment: .leading, spacing: 0) {
                    DetailHeader(operation: operation)
                        .padding(.horizontal, 32)
                        .padding(.top, 32)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            Text(operation.title)
                                .font(.largeTitle)
                                .foregroundStyle(.primary)

                            // 모델 이미지
                            ModelFileListView(assets: operation.assets)

                            // 수술 상세 정보
                            DetailSubPart(
                                title: "수술 상세",
                                content: operation.details
                            )

                            // 환자 정보
                            DetailSubPart(
                                title: "환자 정보",
                                content: "\(patient.name) (\(patient.gender) / \(patient.ageText))"
                            )

                            // 집도의 정보
                            DetailSubPart(
                                title: "집도의",
                                content: operation.surgeon
                            )

                            // 수술 부위 정보
                            DetailSubPart(
                                title: "수술 부위",
                                content: "여기 수정해야함"
                            )

                            // 진단(병명) 정보
                            DetailSubPart(
                                title: "진단(병명)",
                                content: operation.diagnosis
                            )

                            // 수술 날짜 정보
                            DetailSubPart(
                                title: "수술 날짜",
                                content: operation.dateText
                            )
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                    }
                }
                .onDisappear {
                    // 윈도우가 닫힐 때 컨텍스트 정리
                    if appModel.currentOperationContext?.operationID == operationID {
                        appModel.currentOperationContext = nil
                    }
                }
                .toolbar {
                    if !viewModel.isShowingEditInputView {
                        ToolbarItem(placement: .bottomOrnament) {
                            StartOperationButton {
                                Task {
                                    dismissWindow(id: WindowIDs.home)
                                    dismissWindow(id: WindowIDs.operationDetail)
                                    dismissWindow(id: WindowIDs.patientDetail)
                                    let context = OperationContext(
                                        patientID: patientID,
                                        operationID: operationID
                                    )
                                    await openImmersiveSpace(id: ImmersiveIDs.surgery, value: context)
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .environment(viewModel)
        .task {
            await viewModel.load(patientID: patientID, operationID: operationID)
            print("Loaded operation detail for operationID: \(operationID)")
            isLoaded = true
        }
        .onChange(of: appModel.operations) {
            Task {
                await viewModel.load(patientID: patientID, operationID: operationID)
                print("Reloaded operation detail after update")
            }
        }
        .sheet(isPresented: $viewModel.isShowingEditInputView) {
            OperationInputView(mode: .edit(operationID: operationID), patientID: patientID)
        }
    }
}

#Preview {
    OperationDetailView(
        patientID: PatientDisplayModel.MockData.id,
        operationID: OperationDisplayModel.MockData.id
    )
}
