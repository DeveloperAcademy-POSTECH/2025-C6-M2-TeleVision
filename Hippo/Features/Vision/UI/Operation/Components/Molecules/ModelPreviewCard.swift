//
//  ModelPreviewCard.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

// Hippo/Features/Vision/UI/Operation/Components/Molecules/Model3DPreviewCard.swift

import QuickLookThumbnailing
import RealityKit
import SwiftUI

/// 3D 모델 파일을 미리보기로 표시하는 Molecule 컴포넌트
struct ModelPreviewCard: View {
    let asset: OperationAssetDisplayModel
    let size: CGFloat
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    init(
        asset: OperationAssetDisplayModel,
        size: CGFloat = 130,
        isSelected: Bool,
        onSelect: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.asset = asset
        self.size = size
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    @State private var thumbnailImage: Image?

    var body: some View {
        Group {
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.hippoBlack)
                    .frame(width: size, height: size)
                if let image = thumbnailImage {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size - 20, height: size - 20)
                        .onDisappear {
                            asset.fileURL.stopAccessingSecurityScopedResource()
                            print("Stopped access for \(asset.fileName)")
                        }
                } else {
                    ProgressView()
                        .frame(width: size, height: size)
                }

                // 삭제 오버레이
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.hippoBlack)
                        .frame(width: size, height: size)

                    Image(systemName: "trash.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.white)
                }
            }
        }
        .onTapGesture { handleTap() }
        .task {
            await generateThumbnail()
        }
    }

    private func handleTap() {
        if isSelected {
            onDelete()
        } else {
            onSelect()
        }
    }

    /// QLThumbnailGenerator를 사용해 비동기로 썸네일을 생성하는 함수
    private func generateThumbnail() async {
        let generator = QLThumbnailGenerator.shared
        let request = QLThumbnailGenerator.Request(
            fileAt: asset.fileURL,
            size: CGSize(width: size, height: size), // 요청할 썸네일 크기
            scale: 0.5,
            representationTypes: .thumbnail // 썸네일 요청
        )

        do {
            let representation = try await generator.generateBestRepresentation(for: request)
            thumbnailImage = Image(uiImage: representation.uiImage)
            print("썸네일 생성 성공 for \(asset.fileName)")

        } catch {
            print("썸네일 생성 실패: \(error.localizedDescription)")
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
