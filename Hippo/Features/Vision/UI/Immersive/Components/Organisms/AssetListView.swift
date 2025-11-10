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
        VStack {
            HStack {
                Text("3D Asset List")
                    .font(.title)
                Spacer()
            }
            .padding()
            .padding(.leading, 10)
            
            Spacer()
            
            AssetListScrollView(
                fileURLs: fileURLs,
                selectedURL: $selectedURL
            )
            Spacer()
            
            GlowingCapsuleButton(buttonText: "선택하기", action: {
                if let url = selectedURL {
                    Task {
                        immersiveViewModel.selectedAssetURL = url
                        immersiveViewModel.isShowingAssetListView = false
                    }
                }
            })
            .disabled(selectedURL == nil)
            .padding(.bottom, 20)
        }
        .frame(width: 680, height: 440)
        .padding()
        .glassBackgroundEffect()
        .onAppear {
            if selectedURL == nil {
                selectedURL = fileURLs.first
            }
//            if let url = immersiveViewModel.selectedAssetURL {
//                selectedURL = url
//            }
        }
    }
}

#Preview {
    AssetListView()
}
