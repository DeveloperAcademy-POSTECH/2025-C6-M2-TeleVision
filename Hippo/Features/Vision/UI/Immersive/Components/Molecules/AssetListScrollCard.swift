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
    let size: CGFloat = 240
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
            .frame(width: 200, height: 120)
            .padding(.horizontal, 20)
            .onAppear {
                _ = url.startAccessingSecurityScopedResource()
            }
            .onDisappear {
                url.stopAccessingSecurityScopedResource()
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: 40)
                .fill(.quaternary)
                .frame(width: size, height: size)
                .opacity(isSelected ? 1.0 : 0.0)
        }
    }
}
