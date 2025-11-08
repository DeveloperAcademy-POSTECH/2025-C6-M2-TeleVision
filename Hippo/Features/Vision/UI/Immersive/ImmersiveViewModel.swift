//
//  ImmersiveViewModel.swift
//  HippoVision
//
//  Created by yunsly on 11/6/25.
//

import SwiftUI

@Observable
final class ImmersiveViewModel {
    
    // MARK: -- 수술 중 환경 상태
    public var isMenuActive: Bool = true
    public var isEndoscopicActive: Bool = false
    public var isShowingFinishAlert: Bool = false
    public var isShowingAssetListView: Bool = false
    
    // MARK: -- 윈도우 라이프사이클 추적 변수
    public var isSurgeryBottomMenuOpen: Bool = false
    public var isOpacityControlPanelOpen: Bool = false
    public var isEndoscopeStreamWindowOpen: Bool = false
    
    // MARK: -- 이벤트 처리 : UI 이벤트 -> WindowController 에 전달
    
    func showFinishSurgeryAlert() {
        self.isShowingFinishAlert = true
    }
    
    func recordPassThroughVideo() {

    }

    func toggleEndoscope(windowController: WindowController) {
        isEndoscopicActive.toggle()

        if isEndoscopicActive {
            windowController.openWindow(id: WindowIDs.endoscopeStream)
        } else {
            windowController.dismissWindow(id: WindowIDs.endoscopeStream)
        }
    }

    func handleEndoscopeStreamWindowAppear() {
        isEndoscopeStreamWindowOpen = true
    }

    func handleEndoscopeStreamWindowDisappear() {
        isEndoscopeStreamWindowOpen = false
        isEndoscopicActive = false
    }

    func toggleMenu(windowController: WindowController) {
        isMenuActive.toggle()

        if isMenuActive {
            ARSessionController.shared.runARSession()
            if !isSurgeryBottomMenuOpen {
                windowController.openWindow(id: WindowIDs.surgeryBottomMenu)
            }
        } else {
            ARSessionController.shared.stopARSession()
            if isSurgeryBottomMenuOpen {
                windowController.dismissWindow(id: WindowIDs.surgeryBottomMenu)
            }
            
            if isOpacityControlPanelOpen {
                windowController.dismissWindow(id: WindowIDs.opacityControlPanel)
            }
        }
    }
}
