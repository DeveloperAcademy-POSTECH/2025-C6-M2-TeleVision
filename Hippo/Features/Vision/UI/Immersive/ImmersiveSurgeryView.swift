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
    
    // 테스트 용
    @Environment(\.dismissWindow) private var dismissWindow
    
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
                    isAssetListOpen:
                        $viewModel.isShowingAssetListView,
                    isVisible: viewModel.isMenuActive,
                    onOpenEntityPanel: { viewModel.isShowingAssetListView = true },
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
            // 3D 애셋 생성 (AssetListView)
            Attachment(id: AttachmentIDs.assetListView) {
                AssetListView(
                    isPresented: $viewModel.isShowingAssetListView,
                    onCreateEntity: { entityID in
                        Task {
                            let placementService = EntityPlacementService()
                            await runtime.placeEntity(
                                entityID: entityID,
                                service: placementService
                            )
                            viewModel.isShowingAssetListView = false
                        }
                    }
                )
            }
        }
        .task {
            await viewModel.load(patientID: patientID, operationID: operationID)
            // 테스트 용
            Task {
                dismissWindow(id: WindowIDs.home)
            }
        }
        .onChange(of: viewModel.isMenuActive) {
            if viewModel.isMenuActive {
                ARSessionController.shared.runARSession()
            } else {
                ARSessionController.shared.stopARSession()
            }
        }
        .onChange(of: viewModel.isShowingAssetListView) { _, isVisible in
            runtime.setAssetListVisibility(isVisible: isVisible)
        }
        .onChange(of: viewModel.isShowingFinishAlert) { _, isVisible in
            runtime.setFinishAlertVisibility(isVisible: isVisible)
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
