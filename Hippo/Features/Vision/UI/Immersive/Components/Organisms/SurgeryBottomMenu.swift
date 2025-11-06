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
    
    @Environment(OperationViewModel.self) var dataViewModel
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    @Environment(ImmersiveSceneRuntime.self) var runtime
    
    private var patient: PatientDisplayModel {
        dataViewModel.state.patient ?? PatientDisplayModel.MockData
    }
    
    var body: some View {
        let windowController = WindowController(
            dismissSpace: dismissImmersiveSpace,
            openWindow: openWindow,
            dismissWindow: dismissWindow
        )
        
        VStack {
            Spacer()
            
            PatientInfoHeader()
            Spacer().frame(height: 8)
            SurgeryControlBar()
        }
        .opacity(immersiveViewModel.isMenuActive ? 1.0 : 0.0)
        .environment(windowController)
        .ornament(
            visibility: immersiveViewModel.isShowingAssetListView ? .visible : .hidden,
            attachmentAnchor: .scene(.top)) {
                AssetListView()
            }
    }
        
}

#Preview {
    SurgeryBottomMenu()
}
