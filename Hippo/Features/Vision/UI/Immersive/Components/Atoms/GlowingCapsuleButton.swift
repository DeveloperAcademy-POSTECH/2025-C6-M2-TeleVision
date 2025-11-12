//
//  GlowingCapsuleButton.swift
//  Hippo
//
//  Created by yunsly on 10/30/25.
//

import SwiftUI

struct GlowingCapsuleButton: View {
    let buttonText: String
    let action: () -> Void

    var body: some View {
        ZStack {
            Capsule()
                .fill(.hippoPrimary.opacity(0.5))
                .frame(width: 120, height: 48)
                .blur(radius: 10)

            Button(action: action) {
                ZStack {
                    Capsule()
                        .stroke(.white, lineWidth: 5)
                        .fill(.clear)
                        .frame(width: 120, height: 48)
                    Text(buttonText)
                        .font(.title3)
                }
            }
            .buttonStyle(.borderless)
            .contentShape(.capsule)
            .frame(width: 120, height: 48)
            .glassBackgroundEffect(displayMode: .always)
        }
    }
}
