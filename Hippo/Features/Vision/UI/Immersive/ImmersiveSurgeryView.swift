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

    // Voice Control
    @State private var voiceControlVM: VoiceControlViewModel = .init()

    // 생성한 runtime 을 ViewModel에 주입시키기 위한 init
    init(patientID: String, operationID: String) {
        self.patientID = patientID
        self.operationID = operationID
    }

    // MARK: - Computed Properties

    private var windowController: WindowController {
        WindowController(
            dismissSpace: dismissImmersiveSpace,
            openWindow: openWindow,
            dismissWindow: dismissWindow
        )
    }

    // MARK: - Body

    var body: some View {
        @Bindable var immersiveViewModel = immersiveViewModel

        ZStack {
            realityView

            voiceControlUI
        }
        .task { await setupInitialState() }
        .onChange(of: runtime.selectedEntity) { _, newValue in
            handleEntitySelection(newValue)
        }
        .onAppear {
            initializeVoiceControl()
            runtime.start()
        }
        .onDisappear {
            runtime.stop()
        }
    }

    // MARK: - Subviews

    private var realityView: some View {
        RealityView { content, attachments in
            runtime.setupScene(in: content, attachments: attachments)
        } attachments: {
            // Test: Pure hover button (left)
            Attachment(id: AttachmentIDs.testVoiceButton) {
                VoiceControlButton(viewModel: voiceControlVM)
            }

            // Main: Tap + Hover button (right)
            Attachment(id: AttachmentIDs.topToggleButton) {
                VoiceControlMenuButton(viewModel: voiceControlVM) {
                    immersiveViewModel.toggleMenu(windowController: windowController)
                }
            }
        }
    }

    private var voiceControlUI: some View {
        VoiceControlOverlay(viewModel: voiceControlVM)
    }

    // MARK: - Setup & Handlers

    private func initializeVoiceControl() {
        let opacityMgr = OpacityManager(runtime: runtime)
        let voiceMgr = VoiceControlManager(
            runtime: runtime,
            immersiveViewModel: immersiveViewModel,
            opacityManager: opacityMgr,
            dataViewModel: dataViewModel,
            windowController: windowController
        )

        // Update voiceControlVM with actual executor
        voiceControlVM = VoiceControlViewModel(commandExecutor: voiceMgr)
    }

    private func setupInitialState() async {
        await dataViewModel.load(patientID: patientID, operationID: operationID)
        windowController.dismissWindow(id: WindowIDs.home)
        windowController.openWindow(id: WindowIDs.surgeryBottomMenu)
        immersiveViewModel.isMenuActive = true
    }

    private func handleEntitySelection(_ entity: Entity?) {
        if entity != nil && immersiveViewModel.isMenuActive {
            if !immersiveViewModel.isOpacityControlPanelOpen {
                immersiveViewModel.isOpacityControlPanelOpen = true
                windowController.openWindow(id: WindowIDs.opacityControlPanel)
            }
        } else {
            immersiveViewModel.isOpacityControlPanelOpen = false
            windowController.dismissWindow(id: WindowIDs.opacityControlPanel)
        }
    }
}
