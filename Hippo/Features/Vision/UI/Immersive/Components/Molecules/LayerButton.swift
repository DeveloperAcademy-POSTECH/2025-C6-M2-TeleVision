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
            HStack {
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("\(displayedOpacity)%")
                        .font(.callout)
                }
                Spacer()
                
                OpacityControlPanelButton(
                    isVisible: isVisible,
                    buttonType: .eye,
                    onToggle: onEyeToggle
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.leading, 4)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(Color.black.opacity(0.25))))
    //        .animation(.easeInOut, value: isSelected)
            .glassBackgroundEffect()
        }
        .buttonStyle(.plain)
        .padding(0)
        .frame(maxWidth: .infinity)
//        .contentShape(.capsule)
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

