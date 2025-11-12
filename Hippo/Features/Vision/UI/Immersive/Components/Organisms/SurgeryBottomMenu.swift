//
//  SurgeryBottomMenu.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct SurgeryBottomMenu: View {
    
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.pushWindow) private var pushWindow
    
    @Environment(OperationViewModel.self) var dataViewModel
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    @Environment(ImmersiveSceneRuntime.self) var runtime
    
//    @Environment(\.scenePhase) private var scenePhase
    
    private var patient: PatientDisplayModel {
        dataViewModel.state.patient ?? PatientDisplayModel.MockData
    }
    
    var body: some View {
        let windowController = WindowController(
            dismissSpace: dismissImmersiveSpace,
            openWindow: openWindow,
            dismissWindow: dismissWindow,
            pushWindowAction: pushWindow
        )
        
        VStack {
            PatientInfoHeader()
            Spacer().frame(height: 8)
            SurgeryControlBar()
        }
        .environment(windowController)
        .onAppear {
            immersiveViewModel.openMenuSetting(windowController: windowController)
        }
        .onDisappear {
            immersiveViewModel.isMenuActive = false
            immersiveViewModel.closeMenuSetting(windowController: windowController)
        }
//        .onChange(of: scenePhase) { oldPhase, newPhase in
//            // Immersive Space 씬 자체가 닫히거나 백그라운드로 갈 때
//            if newPhase == .background  {
//                print("ImmersiveSurgeryView Scene: 씬 비활성화/백그라운드 감지됨")
//                immersiveViewModel.isMenuActive = false
//                immersiveViewModel.closeMenuSetting(windowController: windowController)
//            }
//        }
    }
    
}

#Preview {
    SurgeryBottomMenu()
}
