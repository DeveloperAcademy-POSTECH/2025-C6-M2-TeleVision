//
//  AssetImageCard.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct AssetImageCard: View {
    let systemImage: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.quaternary)

            Image(systemName: systemImage)
                .font(.system(size: 80))
                .foregroundStyle(color.gradient)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
    }
}

#Preview {
    AssetImageCard(systemImage: "heart.fill", color: .purple)
}
