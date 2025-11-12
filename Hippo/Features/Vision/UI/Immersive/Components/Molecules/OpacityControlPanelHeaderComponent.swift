//
//  OpacityControlPanelHeaderComponent.swift
//  HippoVision
//
//  Created by yunsly on 11/1/25.
//

import SwiftUI

struct OpacityControlPanelHeaderComponent: View {
    let title: String
    let buttonType: OpacityControlPanelButtonType
    let isActive: Bool
    
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.primary)
            
            OpacityControlPanelButton(
                isVisible: isActive,
                buttonType: buttonType,
                onToggle: onToggle
            )
        }
    }
}

#Preview {
    @Previewable @State var isActive = true
    
    HStack {
        OpacityControlPanelHeaderComponent(
            title: "전체 선택",
            buttonType: .check,
            isActive: isActive,
            onToggle: { isActive = $0 }
        )
        
        OpacityControlPanelHeaderComponent(
            title: "전체 보기",
            buttonType: .eye,
            isActive: !isActive,
            onToggle: { isActive = !$0 }
        )
    }
}
