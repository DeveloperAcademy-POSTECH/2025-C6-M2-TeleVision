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

    var body: some View {
        ZStack {
            Circle()
                .fill(.hippoPrimary.opacity(0.5))
                .frame(width: 80, height: 80)
                .blur(radius: 20)

            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 5)
                        .fill(.clear)
                        .frame(width: 80, height: 80)
                    Image(imageName)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
            }
            .buttonStyle(.borderless)
            .contentShape(.circle)
            .frame(width: 80, height: 80)
            .glassBackgroundEffect(displayMode: .always)
        }
    }
}
