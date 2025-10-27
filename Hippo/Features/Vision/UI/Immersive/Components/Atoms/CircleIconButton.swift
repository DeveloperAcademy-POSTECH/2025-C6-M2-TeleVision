//
//  CircleIconButton.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct CircleIconButton: View {
    let systemName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(width: 80, height: 80)
        }
        .buttonStyle(.borderless)
        .contentShape(.circle)
        .frame(width: 80, height: 80)
        .glassBackgroundEffect(displayMode: .always)
    }
}
