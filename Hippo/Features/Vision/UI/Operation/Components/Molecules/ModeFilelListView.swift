//
//  ModeFilelListView.swift
//  Hippo
//
//  Created by 김현기 on 11/1/25.
//

// Hippo/Features/Vision/UI/Operation/Components/Molecules/Model3DFileListView.swift

import SwiftUI

/// 3D 모델 파일 목록을 수평 스크롤로 표시하는 Molecule 컴포넌트
struct ModelFileListView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(OperationViewModel.self) private var viewModel
    let assets: [OperationAssetDisplayModel]
    let isReadOnly: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Spacer().frame(width: 0)

                ForEach(assets, id: \.self.id) { asset in
                    ModelPreviewCard(
                        asset: asset,
                        isReadOnly: isReadOnly,
                        isSelected: viewModel.state.selectedAssetID == asset.id,
                        onSelect: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.selectModelAsset(asset.id)
                            }
                        },
                        onDelete: {
                            print("🗑️ Delete asset with id: \(asset.id)")
                            Task {
                                await viewModel.deleteModelAsset(asset.id)
                                appModel.refreshUI()
                            }
                        }
                    )
                }
            }
            .padding(.vertical)
        }
    }
}

#Preview {
    ModelFileListView(assets: [], isReadOnly: true)
        .frame(height: 150)
        .background(.thinMaterial)
}
