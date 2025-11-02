//
//  SurgeryControlBar.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct SurgeryControlBar: View {
    @Binding var isEndoscopicActive: Bool
    @Binding var isAssetListOpen: Bool
    
    let onOpenEntityPanel: () -> Void
    let onRecord: () -> Void
    let onFinishSurgery: () -> Void
    
    var body: some View {
        HStack {
            CircleIconButton(
                systemName: "iphone.and.arrow.forward.outward",
                buttonSize: 28,
                iconSize: 10,
                action: onFinishSurgery
            )
            
            ZStack {
                HStack {
                    Spacer()
                    if isAssetListOpen {
                        GlowingCircleButton(
                            imageName: "CloseIcon",
                            action: {
                                isAssetListOpen = false
                            }
                        )
                    } else {
                        GlowingCircleButton(
                            imageName: "AddEntityIcon",
                            action: onOpenEntityPanel
                        )
                    }
                    Spacer()
                }
                HStack {
                    EndoscopeToggle(isOn: $isEndoscopicActive)
                    Spacer()
                    RecordButton(action: onRecord)
                }
            }
            .padding(10)
            .frame(width: 180, height: 40)
            .glassBackgroundEffect(in: .capsule, displayMode: .always)
            
            Circle()
                .fill(.clear)
                .frame(width: 28, height: 28)
        }
    }
}


#Preview {
    SurgeryControlBar(
        isEndoscopicActive: .constant(false),
        isAssetListOpen: .constant(false),
        onOpenEntityPanel: {},
        onRecord: {},
        onFinishSurgery: {}
    )
    .padding()
}
