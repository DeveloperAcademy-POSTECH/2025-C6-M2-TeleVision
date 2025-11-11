//
//  AssetListScrollCard.swift
//  HippoVision
//
//  Created by yunsly on 11/2/25.
//

import RealityKit
import SwiftUI

struct AssetListScrollCard: View {
    let url: URL
    let size: CGFloat = 200
    let isSelected: Bool
    
    var body: some View {
        ZStack(alignment: .center) {
            Model3D(url: url) { model in
                model
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: size, height: size)
            .padding(.horizontal, 20)
            .onAppear {
                _ = url.startAccessingSecurityScopedResource()
            }
            .onDisappear {
                url.stopAccessingSecurityScopedResource()
            }
        }
        .frame(width: size, height: size)
    }
}
