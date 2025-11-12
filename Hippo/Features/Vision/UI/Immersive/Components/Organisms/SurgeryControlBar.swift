//
//  SurgeryControlBar.swift
//  Hippo
//
//  Created by 김현기 on 10/27/25.
//

import SwiftUI

struct SurgeryControlBar: View {
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    @Environment(WindowController.self) var windowController
    
    var body: some View {
        @Bindable var immersiveViewModel = immersiveViewModel
        
        HStack {
            CircleIconButton(
                systemName: "iphone.and.arrow.forward.outward",
                buttonSize: 60,
                iconSize: 24,
                action: { immersiveViewModel.showFinishSurgeryAlert() }
            )
            
            ZStack {
                HStack {
                    Spacer()
                    if immersiveViewModel.isShowingAssetListView {
                        GlowingCircleButton(
                            imageName: "CloseIcon",
                            action: {
                                windowController.dismissWindow(id: WindowIDs.assetListView)
                            }
                        )
                    } else {
                        GlowingCircleButton(
                            imageName: "AddEntityIcon",
                            action: {
                                windowController.pushWindow(id: WindowIDs.assetListView)
                                immersiveViewModel.isShowingAssetListView = true
                                
                            }
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassBackgroundEffect(in: .capsule, displayMode: .always)
            .frame(width: 420)
            
            Circle()
                .fill(.clear)
                .frame(width: 60, height: 60)
        }
        .alert("수술을 종료하시겠습니까?", isPresented: $immersiveViewModel.isShowingFinishAlert) {
            Button("종료", role: .destructive) {
                Task {
                    await windowController.finishSurgeryAndDismissSpace()
                    if immersiveViewModel.isOpacityControlPanelOpen {
                        windowController.dismissWindow(id: WindowIDs.opacityControlPanel)
                        immersiveViewModel.isOpacityControlPanelOpen = false
                    }
                }
            }
            Button("취소", role: .cancel) {
                immersiveViewModel.isShowingFinishAlert = false
            }
        } message : {
            Text("나가면 다시 돌아올 수는 있지만, 현재 상태가 초기화될 수 있습니다.")
        }
    }
}


#Preview {
    SurgeryControlBar()
        .padding()
}
