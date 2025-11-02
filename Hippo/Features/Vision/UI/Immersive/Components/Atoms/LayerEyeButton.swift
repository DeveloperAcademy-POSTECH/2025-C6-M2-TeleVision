//
//  LayerEyeButton.swift
//  Hippo
//
//  Created by yunsly on 10/31/25.
//

import SwiftUI

struct LayerEyeButton: View {
    
    let isVisible: Bool
    let size: CGFloat
    let iconSize: CGFloat
    
    let onToggle: (Bool) -> Void
    
    var body: some View {
        ZStack {
            if isVisible {
                Circle()
                    .fill(Color.hippoPrimary.opacity(0.5))
                    .frame(width: size, height: size)
                    .blur(radius: 4)
            }
            Button {
                onToggle(!isVisible)
            } label: {
                ZStack {
                    backgroundView
                    iconView
                    if isVisible {
                        Circle()
                            .stroke(.white, lineWidth: 3)
                            .frame(width: size, height: size)
                    }
                }
            }
            .buttonStyle(.borderless)
            .frame(width: size, height: size)
            .contentShape(.circle)
            .glassBackgroundEffect(displayMode: .always)
        }
    }
}

private extension LayerEyeButton {
    var imageName: String { isVisible ? "eye" : "eye.slash" }
    
    var iconView: some View {
        Image(systemName: imageName)
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(isVisible ? .primary : .quaternary)
    }
    

    @ViewBuilder
    var backgroundView: some View {
        if !isVisible {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(.systemGray2), Color(.systemGray3)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
        }
    }
}

#Preview {
    @Previewable @State var isVisible = true
    
    LayerEyeButton(isVisible: isVisible, size: 40, iconSize: 20) { newValue in
        isVisible = newValue
    }
}
