//
//  MenuToggleButton.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct MenuToggleButton: View {
    
    @Environment(ImmersiveViewModel.self) private var immersiveViewModel
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Image("TopButton")
            .resizable()
            .frame(width: 120, height: 120)
            .opacity(immersiveViewModel.isMenuActive ? 1.0 : 0.25)
            .onTapGesture(perform: action)
    }
}

#Preview {
    VStack(spacing: 20) {
        MenuToggleButton(isActive: true, action: {})
        MenuToggleButton(isActive: false, action: {})
    }
}
