//
//  SurgeryBottomMenu.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct SurgeryBottomMenu: View {
    
    @Environment(OperationViewModel.self) var dataViewModel
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    @Environment(WindowController.self) var windowController
    
    private var patient: PatientDisplayModel {
        dataViewModel.state.patient ?? PatientDisplayModel.MockData
    }
    
    var body: some View {
        VStack {
            PatientInfoHeader()
            Spacer().frame(height: 6)
            
            SurgeryControlBar()
        }
        .opacity(immersiveViewModel.isMenuActive ? 1.0 : 0.0)
    }
}

#Preview {
    SurgeryBottomMenu()
}
