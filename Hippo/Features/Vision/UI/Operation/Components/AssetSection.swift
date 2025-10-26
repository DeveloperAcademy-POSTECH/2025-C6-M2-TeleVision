//
//  AssetSection.swift
//  HippoVision
//
//  Created by 김현기 on 10/21/25.
//

import SwiftUI

struct AssetSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 24) {
                // 왼쪽 간 이미지
                AssetImageCard(
                    systemImage: "heart.fill",
                    color: .purple
                )

                // 오른쪽 간 이미지
                AssetImageCard(
                    systemImage: "lungs.fill",
                    color: .red
                )
            }
        }
    }
}

#Preview {
    AssetSection()
}
