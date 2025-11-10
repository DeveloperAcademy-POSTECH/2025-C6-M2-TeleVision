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
    public var isShowingAssetListView: Bool = true
    
    // MARK: -- 객체 생성 관련 상태 추가
    public var selectedAssetURL: URL? = nil // AssetListView에서 선택된 URL
    
    // MARK: -- 윈도우 라이프사이클 추적 변수
    public var isSurgeryBottomMenuOpen: Bool = false
    public var isEntitySettingPanelOpen: Bool = false
    
    // MARK: -- 이벤트 처리 : UI 이벤트 -> WindowController 에 전달
    
    func showFinishSurgeryAlert() {
        self.isShowingFinishAlert = true
    }
    
    func recordPassThroughVideo() {
        
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
            
            if isEntitySettingPanelOpen {
                windowController.dismissWindow(id: WindowIDs.entitySettingPanel)
            }
        }
    }
}
