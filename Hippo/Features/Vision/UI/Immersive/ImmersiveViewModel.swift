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
    public var isSurgeryBottomMenuOpen: Bool = true
    public var isOpacityControlPanelOpen: Bool = false
    
    
    // MARK: -- 이벤트 처리 : UI 이벤트 -> WindowController 에 전달
    
    func showFinishSurgeryAlert() {
        self.isShowingFinishAlert = true
    }
    
    func recordPassThroughVideo() {
        
    }
    
    func resetSetting() {
        isMenuActive = true
        isEndoscopicActive = false
        isShowingFinishAlert = false
        isShowingAssetListView = false
        
        isSurgeryBottomMenuOpen = true
        isOpacityControlPanelOpen = false
        print("reset")
    }
    
    // 컨트롤러 on
    func openMenuSetting(windowController: WindowController) {
        ARSessionController.shared.runARSession()
        if !isSurgeryBottomMenuOpen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                windowController.openWindow(id: WindowIDs.surgeryBottomMenu)
                self.isSurgeryBottomMenuOpen = true
            }
        }
    }
    
    // 컨트롤러 off
    func closeMenuSetting(windowController: WindowController) {
        ARSessionController.shared.stopARSession()
        if isSurgeryBottomMenuOpen {
            windowController.dismissWindow(id: WindowIDs.surgeryBottomMenu)
            isSurgeryBottomMenuOpen = false
        }
        if isOpacityControlPanelOpen {
            windowController.dismissWindow(id: WindowIDs.opacityControlPanel)
            isOpacityControlPanelOpen = false
        }
        if isShowingAssetListView {
            windowController.dismissWindow(id: WindowIDs.assetListView)
            isShowingAssetListView = false
        }
    }
    
    func toggleMenu(windowController: WindowController) {
        isMenuActive.toggle()

        if isMenuActive {
            openMenuSetting(windowController: windowController)
        } else {
            closeMenuSetting(windowController: windowController)
        }
    }
}
