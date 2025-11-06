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
    @Environment(\.dismissWindow) private var dismissWindow
    
    let patientID: String
    let operationID: String
    
    @State private var runtime: ImmersiveSceneRuntime
    @State private var dataViewModel: OperationViewModel
    @State private var opacityViewModel: OpacityControlViewModel
    @State private var immersiveViewModel: ImmersiveViewModel
    
    private var patient: PatientDisplayModel {
        guard let patient = dataViewModel.state.patient else {
            return PatientDisplayModel.MockData
        }
        return patient
    }
    
    private var operation: OperationDisplayModel {
        guard let operation = dataViewModel.state.operation else {
            return OperationDisplayModel.MockData
        }
        return operation
    }
    
    // 생성한 runtime 을 ViewModel에 주입시키기 위한 init
    init(patientID: String, operationID: String) {
        self.patientID = patientID
        self.operationID = operationID
        
        let runtime = ImmersiveSceneRuntime()
        self._runtime = State(initialValue: runtime)
        self._immersiveViewModel = State(initialValue: ImmersiveViewModel())
        self._opacityViewModel = State(initialValue: OpacityControlViewModel(runtime: runtime))
        self._dataViewModel = State(initialValue: OperationViewModel())
    }
    
    var body: some View {
        RealityView { content, attachments in
            runtime.setupScene(in: content, attachments: attachments)
        } attachments: {
            // 상단 토글 아이콘
            Attachment(id: AttachmentIDs.topToggleButton) {
                MenuToggleButton(isActive: immersiveViewModel.isMenuActive) {
                    // 메뉴 토글
                    immersiveViewModel.isMenuActive.toggle()
                }
            }
            // 하단 메뉴 바
            Attachment(id: AttachmentIDs.bottomMenuBar) {
                SurgeryBottomMenu(
                    patient: patient,
                    isEndoscopicActive: $immersiveViewModel.isEndoscopicActive,
                    isAssetListOpen:
                        $immersiveViewModel.isShowingAssetListView,
                    isVisible: immersiveViewModel.isMenuActive,
                    onOpenEntityPanel: { immersiveViewModel.isShowingAssetListView = true },
                    onRecord: immersiveViewModel.recordPassThroughVideo,
                    onFinishSurgery: { immersiveViewModel.isShowingFinishAlert = true }
                )
            }
//            // 수술 나가기 Alert
//            Attachment(id: AttachmentIDs.finishSurgeryAlert) {
//                HippoAlertView(
//                    isPresented: $dataViewModel.isShowingFinishAlert
//                ) {
//                    Task {
//                        await dismissImmersiveSpace()
//                        openWindow(id: WindowIDs.home)
//                    }
//                }
//            }
//            // 3D 애셋 생성 (AssetListView)
//            Attachment(id: AttachmentIDs.assetListView) {
//                AssetListView(
//                    isPresented: $dataViewModel.isShowingAssetListView,
//                    operation: operation,
//                    onCreateEntity: { url in
//                        Task {
//                            await runtime.placeEntity(url: url)
//                            dataViewModel.isShowingAssetListView = false
//                        }
//                    }
//                )
//            }
//            // Opacity Control Panel
//            Attachment(id: AttachmentIDs.opacityControlPanel) {
//                OpacityControlPanel(viewModel: opacityViewModel)
//            }
        }
        .environment(runtime)
        .environment(dataViewModel)
        .environment(immersiveViewModel)
        .environment(opacityViewModel)
        .environment(WindowController(
            dismissSpace: dismissImmersiveSpace,
            openWindow: openWindow,
            dismissWindow: dismissWindow)
        )
        .task {
            await dataViewModel.load(patientID: patientID, operationID: operationID)
            dismissWindow(id: WindowIDs.home)
        }
        
        
//        .onChange(of: dataViewModel.isMenuActive) {
//            if dataViewModel.isMenuActive {
//                ARSessionController.shared.runARSession()
//                
//            } else {
//                ARSessionController.shared.stopARSession()
//            }
//            runtime.setOpacityPanelVisibility(isVisible: dataViewModel.isMenuActive)
//        }
//        .onChange(of: dataViewModel.isShowingAssetListView) { _, isVisible in
//            runtime.setAssetListVisibility(isVisible: isVisible)
//            runtime.setOpacityPanelVisibility(isVisible: !isVisible)
//        }
//        .onChange(of: dataViewModel.isShowingFinishAlert) { _, isVisible in
//            runtime.setFinishAlertVisibility(isVisible: isVisible)
//        }
//        .onChange(of: runtime.selectedEntity) { _, newValue in
//            runtime.setOpacityPanelVisibility(isVisible: newValue != nil)
//        }
//        .onAppear { runtime.start() }
//        .onDisappear { runtime.stop() }
    }
}

#Preview {
    ImmersiveSurgeryView(
        patientID: PatientDisplayModel.MockData.id,
        operationID: OperationDisplayModel.MockData.id
    )
}
