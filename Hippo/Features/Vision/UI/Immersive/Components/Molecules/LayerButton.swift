//
//  LayerButton.swift
//  Hippo
//
//  Created by yunsly on 10/31/25.
//

import SwiftUI

struct LayerButton: View {
    
    let title: String
    let opacity: Float
    let isSelected: Bool
    let isVisible: Bool
    
    let onSelect: (Bool) -> Void
    let onEyeToggle: (Bool) -> Void
    
    private var displayedOpacity: Int { Int(opacity * 100) }
    
    var body: some View {
        Button {
            onSelect(!isSelected)
        } label: {
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.subheadline)
                    Text("\(displayedOpacity)%")
                        .font(.headline)
                }
                
                OpacityControlPanelButton(
                    isVisible: isVisible,
                    buttonType: .eye,
                    onToggle: onEyeToggle
                )
            }
        }
        .contentShape(.capsule)
        .background(
            Capsule().fill(isSelected ? .secondary : .quaternary))
        .frame(width: 150, height: 74)
        .animation(.easeInOut, value: isSelected)
    }
}

#Preview {
    @Previewable @State var isSelected = false
    @Previewable @State var isVisible = true
    
    LayerButton(
        title: "Layer 1",
        opacity: 0.85,
        isSelected: isSelected,
        isVisible: isVisible,
        onSelect: { isSelected = $0 },
        onEyeToggle: { isVisible = $0 }
    )
}
