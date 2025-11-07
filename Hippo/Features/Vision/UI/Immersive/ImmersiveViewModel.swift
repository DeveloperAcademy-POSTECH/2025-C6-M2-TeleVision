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
    
    // MARK: -- 이벤트 처리 : UI 이벤트 -> WindowController 에 전달
    
    func showFinishSurgeryAlert() {
        self.isShowingFinishAlert = true
    }
    
    
    func recordPassThroughVideo() {
        
    }
    
    func toggleMenu(windowController: WindowController) {
        isMenuActive.toggle()
        
        // AR Session 관리
        // TODO: 컨트롤러 상태에 따른 메뉴바 및 패널 시각화 조정
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
