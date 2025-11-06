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
    
    @Environment(ImmersiveSceneRuntime.self) private var runtime
    @Environment(ImmersiveViewModel.self) private var immersiveViewModel
    
    let patientID: String
    let operationID: String
    
    @State private var dataViewModel: OperationViewModel

    // 생성한 runtime 을 ViewModel에 주입시키기 위한 init
    init(patientID: String, operationID: String) {
        self.patientID = patientID
        self.operationID = operationID
        
        self._dataViewModel = State(initialValue: OperationViewModel())
    }
    
    var body: some View {
        let windowController = WindowController(
            dismissSpace: dismissImmersiveSpace,
            openWindow: openWindow,
            dismissWindow: dismissWindow
        )
        
        @Bindable var immersiveViewModel = immersiveViewModel
        
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
                SurgeryBottomMenu()
            }
            // 3D 애셋 생성 (AssetListView)
            Attachment(id: AttachmentIDs.assetListView) {
                AssetListView()
            }
        }
        .environment(runtime)
        .environment(dataViewModel)
        .environment(immersiveViewModel)
        .environment(windowController)
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
        .onChange(of: immersiveViewModel.isShowingAssetListView) { _, isVisible in
            runtime.setAssetListVisibility(isVisible: isVisible)
        }

        .onChange(of: runtime.selectedEntity) { _, newValue in
            if newValue != nil {
                windowController.openWindow(id: WindowIDs.opacityControlPanel)
            } else {
                windowController.dismissWindow(id: WindowIDs.opacityControlPanel)
            }
        }
        .alert("수술을 종료하시겠습니까?", isPresented: $immersiveViewModel.isShowingFinishAlert) {
            Button("종료", role: .destructive) {
                Task {
                    await windowController.finishSurgeryAndDismissSpace()
                }
            }
            Button("취소", role: .cancel) { }
        } message : {
            Text("나가면 다시 돌아올 수는 있지만, 현재 상태가 초기화될 수 있습니다.")
        }
        .onAppear { runtime.start() }
        .onDisappear {
            runtime.stop()
            windowController.dismissWindow(id: WindowIDs.opacityControlPanel)
            
        }
    }
}

//#Preview {
//    ImmersiveSurgeryView(
//        patientID: PatientDisplayModel.MockData.id,
//        operationID: OperationDisplayModel.MockData.id
//    )
//}
