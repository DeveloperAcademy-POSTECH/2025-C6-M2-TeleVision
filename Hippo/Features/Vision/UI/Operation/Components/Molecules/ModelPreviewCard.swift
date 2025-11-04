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
//    let url: URL
    let asset: OperationAssetDisplayModel
    let size: CGFloat

    init(asset: OperationAssetDisplayModel, size: CGFloat = 130) {
        self.asset = asset
        self.size = size
    }

    var body: some View {
        Group {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.hippoBlack)
                    .frame(width: size, height: size)
                Model3D(url: asset.fileURL) { model in
                    model
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: size - 20, height: size - 20)
                .onDisappear {
                    asset.fileURL.stopAccessingSecurityScopedResource()
                    print("Stopped access for \(asset.fileName)")
                }
            }
        }
    }
}

// #Preview {
//    ModelPreviewCard(
//        asset: OperationAssetDisplayModel(
//
//        )
//    )
//    .padding()
// }
