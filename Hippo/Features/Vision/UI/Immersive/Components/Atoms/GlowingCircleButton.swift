//
//  GlowingCircleButton.swift
//  Hippo
//
//  Created by 김현기 on 10/26/25.
//

import SwiftUI

struct GlowingCircleButton: View {
    let imageName: String
    let action: () -> Void
    let size: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .fill(.hippoPrimary.opacity(0.5))
                .frame(width: size, height: size)
                .blur(radius: 16)

            Button(action: action) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 1)
                        .frame(width: size, height: size)
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 2, y: 2)
                }
            }
            .buttonStyle(.borderless)
            .contentShape(.circle)
            .frame(width: size, height: size)
            .glassBackgroundEffect(displayMode: .always)
        }
    }
}
