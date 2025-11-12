//
//  AssetListView.swift
//  Hippo
//
//  Created by yunsly on 10/30/25.
//

import SwiftUI

struct AssetListView: View {
    
    // ImmersiveView에서 주입된 모델들 참조
    @Environment(ImmersiveSceneRuntime.self) var runtime
    @Environment(OperationViewModel.self) var dataViewModel
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    
    @Environment(\.dismissWindow) private var dismissWindow
    
    @State private var selectedURL: URL?
    
    private var fileURLs: [URL] {
        dataViewModel.state.operation?.assets.map { $0.fileURL } ?? []
    }
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("3D Asset List")
                    .font(.title)
                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 28)
            
            
            AssetListScrollView(
                fileURLs: fileURLs,
                selectedURL: $selectedURL
            )
            
            GlowingCapsuleButton(buttonText: "생성하기", action: {
                if let url = selectedURL {
                    Task {
                        await runtime.placeEntity(url: url)
                        immersiveViewModel.isShowingAssetListView = false
                        dismissWindow(id: WindowIDs.assetListView)
                    }
                }
            })
            .disabled(selectedURL == nil)
            .padding(.vertical, 20)
        }
        .frame(width: 600)
        .glassBackgroundEffect()
        .onAppear {
            if selectedURL == nil {
                selectedURL = fileURLs.first
            }
        }
        .onDisappear {
            immersiveViewModel.isShowingAssetListView = false
        }
        
    }
}

#Preview {
    AssetListView()
}
