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
    @Environment(OperationViewModel.self) private var dataViewModel: OperationViewModel
    
    let patientID: String
    let operationID: String

    // 생성한 runtime 을 ViewModel에 주입시키기 위한 init
    init(patientID: String, operationID: String) {
        self.patientID = patientID
        self.operationID = operationID
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
                MenuToggleButton() {
                    // 메뉴 토글
                    immersiveViewModel.toggleMenu(windowController: windowController)
                }
            }
        }
        .task {
            await dataViewModel.load(patientID: patientID, operationID: operationID)
            windowController.dismissWindow(id: WindowIDs.home)
            windowController.openWindow(id: WindowIDs.surgeryBottomMenu)
        }
        .onChange(of: runtime.selectedEntity) { _, newValue in
            if newValue != nil && immersiveViewModel.isMenuActive { // 컨트롤러 on 일 때만 열림
                // 창이 켜져 있으면 정보만 재로드 (OpactiyControlPanel에서 처리됨)
                if !immersiveViewModel.isEntitySettingPanelOpen {
                    // 창이 꺼져 있으면 새로운 창 띄우기
                    windowController.openWindow(id: WindowIDs.entitySettingPanel)
                }
            } else {
                // selectedEntity가 nil이 되거나, 메뉴가 꺼지면 창 닫기
                windowController.dismissWindow(id: WindowIDs.entitySettingPanel)
            }
        }
        
        .onAppear { runtime.start() }
        .onDisappear {
            runtime.stop()
        }
    }
}

