//
//  VoiceControlManager.swift
//  Hippo
//
//  Created by yunsly on 11/13/25.
//

import SwiftUI

final class VoiceControlManager {
    let runtime: ImmersiveSceneRuntime
    let immersiveViewModel: ImmersiveViewModel
    let opacityManager: OpacityManager
    let dataViewModel: OperationViewModel
    let windowController: WindowController
    
    init(runtime: ImmersiveSceneRuntime, immersiveViewModel: ImmersiveViewModel, opacityManager: OpacityManager, dataViewModel: OperationViewModel, windowController: WindowController) {
        self.runtime = runtime
        self.immersiveViewModel = immersiveViewModel
        self.opacityManager = opacityManager
        self.dataViewModel = dataViewModel
        self.windowController = windowController
    }
    
    func openHeadController() {
        immersiveViewModel.openMenuSetting(windowController: windowController)
    }
    
    func closeHeadController() {
        immersiveViewModel.closeMenuSetting(windowController: windowController)
    }
    
    func openEndoscopicView() {
        if immersiveViewModel.isEndoscopicActive {
            immersiveViewModel.toggleEndoscope()
        }
    }
    
    func closeEndoscopicView() {
        if !immersiveViewModel.isEndoscopicActive {
            immersiveViewModel.toggleEndoscope()
        }
    }
    
    // 등록된 엔티티 중 i번째 엔티티 생성
    func addEntity(index: Int) {
        var fileURLs: [URL] {
            dataViewModel.state.operation?.assets.map { $0.fileURL } ?? []
        }
        
        guard let selectedURL = fileURLs.indices.contains(index) ? fileURLs[index] : nil else {
            return
        }
        
        Task {
            await runtime.placeEntity(url: selectedURL)
        }
    }
    
    

}
