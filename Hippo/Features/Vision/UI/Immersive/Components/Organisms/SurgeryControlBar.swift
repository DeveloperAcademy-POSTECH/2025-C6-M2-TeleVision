//
//  SurgeryControlBar.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct SurgeryControlBar: View {
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    
    var body: some View {
        @Bindable var immersiveViewModel = immersiveViewModel
        
        HStack {
            CircleIconButton(
                systemName: "iphone.and.arrow.forward.outward",
                buttonSize: 80,
                iconSize: 28,
                action: { immersiveViewModel.showFinishSurgeryAlert() }
            )
            
            ZStack {
                HStack {
                    Spacer()
                    if immersiveViewModel.isShowingAssetListView {
                        GlowingCircleButton(
                            imageName: "CloseIcon",
                            action: {
                                immersiveViewModel.closeAssetListView()
                            }
                        )
                    } else {
                        GlowingCircleButton(
                            imageName: "AddEntityIcon",
                            action: { immersiveViewModel.openAssetListView() }
                        )
                    }
                    Spacer()
                }
                HStack {
                    EndoscopeToggle(isOn: $immersiveViewModel.isEndoscopicActive)
                    Spacer()
                    RecordButton(action: immersiveViewModel.recordPassThroughVideo)
                }
            }
            .padding(10)
            .frame(width: 680, height: 120)
            .glassBackgroundEffect(in: .capsule, displayMode: .always)
            
            Circle()
                .fill(.clear)
                .frame(width: 80, height: 80)
        }
    }
}


#Preview {
    SurgeryControlBar()
    .padding()
}
