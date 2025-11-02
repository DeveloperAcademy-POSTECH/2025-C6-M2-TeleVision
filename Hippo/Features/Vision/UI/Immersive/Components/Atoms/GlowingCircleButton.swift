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
    let size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle()
                .fill(.hippoPrimary.opacity(0.5))
                .frame(width: size, height: size)
                .blur(radius: 4)

            Button(action: action) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: 1)
                        .frame(width: size, height: size)
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
            }
            .buttonStyle(.borderless)
            .contentShape(.circle)
            .frame(width: size, height: size)
            .glassBackgroundEffect(displayMode: .always)
        }
    }
}
