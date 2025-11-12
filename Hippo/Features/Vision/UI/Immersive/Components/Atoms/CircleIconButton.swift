//
//  CircleIconButton.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct CircleIconButton: View {
    let systemName: String
    let buttonSize: CGFloat
    let iconSize: CGFloat
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .contentShape(.circle)
        .frame(width: buttonSize, height: buttonSize)
        .glassBackgroundEffect(displayMode: .always)
    }
}
