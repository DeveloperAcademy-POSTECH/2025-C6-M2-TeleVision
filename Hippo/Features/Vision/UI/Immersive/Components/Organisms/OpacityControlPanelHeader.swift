//
//  OpacityControlPanelHeader.swift
//  HippoVision
//
//  Created by yunsly on 11/1/25.
//

import SwiftUI

struct OpacityControlPanelHeader: View {
    let isAllSelected: Bool
    let isAllVisible: Bool
    
    let onDeleteTapped: () -> Void
    let onSelectAllToggle: (Bool) -> Void
    let onShowAllToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            CircleIconButton(systemName: "trash",
                             buttonSize: 40,
                             iconSize: 16,
                             action: onDeleteTapped)
            Spacer()
            
            OpacityControlPanelHeaderComponent(
                title: "전체 선택",
                buttonType: .check,
                isActive: isAllSelected,
                onToggle: onSelectAllToggle
            )
            .padding(.trailing, 16)
            
            OpacityControlPanelHeaderComponent(
                title: "전체 보기",
                buttonType: .eye,
                isActive: isAllVisible,
                onToggle: onShowAllToggle
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

#Preview {
    @Previewable @State var isAllSelected = false
    @Previewable @State var isAllVisible = true
    
    OpacityControlPanelHeader(
        isAllSelected: isAllSelected,
        isAllVisible: isAllVisible,
        onDeleteTapped: {},
        onSelectAllToggle: { isAllSelected = $0 },
        onShowAllToggle: { isAllVisible = $0 }
    )
    .padding()
    .glassBackgroundEffect()
}
