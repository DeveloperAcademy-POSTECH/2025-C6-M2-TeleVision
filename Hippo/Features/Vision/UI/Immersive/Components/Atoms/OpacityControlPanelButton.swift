//
//  OpacityControlPanelButton.swift
//  HippoVision
//
//  Created by yunsly on 11/1/25.
//

import SwiftUI

enum OpacityControlPanelButtonType {
    case check, eye
}

struct OpacityControlPanelButton: View {
    
    let isVisible: Bool
    let size: CGFloat = 40
    let iconSize: CGFloat = 20
    let buttonType: OpacityControlPanelButtonType
    
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

private extension OpacityControlPanelButton {
    var imageName: String {
        switch buttonType {
        case .check:
            return "checkmark"
        case .eye:
            return isVisible ? "eye" : "eye.slash"
        }
    }
    
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
    
    OpacityControlPanelButton(isVisible: isVisible, buttonType: .check) { newValue in
        isVisible = newValue
    }
    
    OpacityControlPanelButton(isVisible: isVisible, buttonType: .eye) { newValue in
        isVisible = newValue
    }
}
