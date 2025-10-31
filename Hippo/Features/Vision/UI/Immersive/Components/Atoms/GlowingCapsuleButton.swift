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
                .frame(width: 160, height: 60)
                .blur(radius: 5)

            Button(action: action) {
                ZStack {
                    Capsule()
                        .stroke(.white, lineWidth: 5)
                        .fill(.clear)
                        .frame(width: 160, height: 60)
                    Text(buttonText)
                        .font(.title2)
                }
            }
            .buttonStyle(.borderless)
            .contentShape(.capsule)
            .frame(width: 160, height: 60)
            .glassBackgroundEffect(displayMode: .always)
        }
    }
}
