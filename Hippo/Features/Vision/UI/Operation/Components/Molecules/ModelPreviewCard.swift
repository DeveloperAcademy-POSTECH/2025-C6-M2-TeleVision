//
//  ModelPreviewCard.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

// Hippo/Features/Vision/UI/Operation/Components/Molecules/Model3DPreviewCard.swift

import RealityKit
import SwiftUI

/// 3D 모델 파일을 미리보기로 표시하는 Molecule 컴포넌트
struct ModelPreviewCard: View {
    let url: URL
    let size: CGFloat

    init(url: URL, size: CGFloat = 130) {
        self.url = url
        self.size = size
    }

    var body: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.hippoBlack)
                .frame(width: size, height: size)

            Model3D(url: url) { model in
                model
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                ProgressView()
            }
            .frame(width: size - 20, height: size - 20)
            .onAppear {
                _ = url.startAccessingSecurityScopedResource()
            }
            .onDisappear {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
}

#Preview {
    ModelPreviewCard(
        url: Bundle.main.url(forResource: "sample", withExtension: "usdz")!
    )
    .padding()
}
