//
//  EntitySettingPanel.swift
//  HippoVision
//
//  Created by yunsly on 11/9/25.
//

import SwiftUI

struct EntitySettingPanel: View {
    @Environment(ImmersiveViewModel.self) var immersiveViewModel
    
    var body: some View {
        @Bindable var immersiveViewModel = immersiveViewModel
        
        HStack {
            // TODO: 객체 미리보기 추가
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
