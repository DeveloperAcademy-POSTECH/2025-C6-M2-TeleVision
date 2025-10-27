//
//  ImmersiveSurgeryView.swift
//  HippoVision
//
//  Created by 김현기 on 10/24/25.
//

import RealityKit
import SwiftUI

struct ImmersiveSurgeryView: View {
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    let patientID: String
    let operationID: String

    @State private var runtime = ImmersiveSceneRuntime()
    @State private var viewModel = OperationViewModel()

    private var patient: PatientDisplayModel {
        guard let patient = viewModel.state.patient else {
            return PatientDisplayModel.MockData
        }
        return patient
    }

    private var operation: OperationDisplayModel {
        guard let operation = viewModel.state.operation else {
            return OperationDisplayModel.MockData
        }
        return operation
    }

    var body: some View {
        RealityView { content, attachments in
            runtime.setupScene(in: content, attachments: attachments)
        } attachments: {
            // 상단 토글 아이콘
            Attachment(id: AttachmentIDs.topToggleButton) {
                MenuToggleButton(isActive: viewModel.isMenuActive) {
                    // 메뉴 토글
                    viewModel.isMenuActive.toggle()
                }
            }
            // 하단 메뉴 바
            Attachment(id: AttachmentIDs.bottomMenuBar) {
                SurgeryBottomMenu(
                    patient: patient,
                    isEndoscopicActive: $viewModel.isEndoscopicActive,
                    isVisible: viewModel.isMenuActive,
                    onOpenEntityPanel: viewModel.openEntityPanel,
                    onRecord: viewModel.recordPassThroughVideo,
                    onFinishSurgery: { viewModel.isShowingFinishAlert = true }
                )
            }
            // 수술 나가기 Alert
            Attachment(id: AttachmentIDs.finishSurgeryAlert) {
                HippoAlertView(
                    isPresented: $viewModel.isShowingFinishAlert
                ) {
                    Task {
                        await dismissImmersiveSpace()
                        openWindow(id: WindowIDs.home)
                    }
                }
            }
        }
        .task {
            await viewModel.load(patientID: patientID, operationID: operationID)
        }
        .onAppear { runtime.start() }
        .onDisappear { runtime.stop() }
    }
}

#Preview {
    ImmersiveSurgeryView(
        patientID: PatientDisplayModel.MockData.id,
        operationID: OperationDisplayModel.MockData.id
    )
}
