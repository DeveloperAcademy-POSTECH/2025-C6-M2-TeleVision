//
//  EntitySettingPanel.swift
//  HippoVision
//
//  Created by yunsly on 11/9/25.
//

import SwiftUI
import RealityKit

struct EntitySettingPanel: View {
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    @State private var entityPreview = EntityPreview()
    @State private var previewAnchor = AnchorEntity()
    
    var body: some View {
        @Bindable var immersiveViewModel = immersiveViewModel
        
        HStack {
            RealityView { content in
                content.add(previewAnchor)
            }
            .onChange(of: immersiveViewModel.selectedAssetURL) { _, newURL in
                if let url = newURL {
                    Task { await entityPreview.loadEntity(from: url, anchor: previewAnchor) }
                }
            }
            .frame(width: 594, height: 638)
            
            Spacer()
            
            LayerControlView()
                .frame(width: 674)
                .background(Color.black.opacity(0.1))
        }
        .sheet(isPresented: $immersiveViewModel.isShowingAssetListView) {
            AssetListView()
        }
    }
    
}

#Preview {
    EntitySettingPanel()
}
