//
//  OpacityControlPanel.swift
//  Hippo
//
//  Created by yunsly on 11/1/25.
//

import SwiftUI
import RealityKit

struct OpacityControlPanel: View {
    
    @Bindable var viewModel: OpacityManager
    @Environment(ImmersiveSceneRuntime.self) var runtime
    
    // Grid 레이아웃 설정 (4열)
    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack {
            OpacityControlPanelHeader(
                isAllSelected: viewModel.isAllSelected,
                isAllVisible: viewModel.isAllVisible,
                onDeleteTapped: {
                    Task {
                        await runtime.deleteSelectedEntity()
                    }
                },
                onSelectAllToggle: { shouldSelectAll in
                    viewModel.selectAllLayers(shouldSelectAll: shouldSelectAll)
                },
                onShowAllToggle: {_ in
                    viewModel.setVisibilityForAll(to: !viewModel.isAllVisible)
                }
            )
            
            // 투명도 슬라이더
            OpacityControlSlider(
                currentOpacity: $viewModel.currentOpacity,
                selectedLayerIDS: viewModel.selectedLayerIDs,
                isMixed: viewModel.isMixed
            )
            
            // 2. 레이어 버튼 그리드
            if viewModel.hasAnyLayers {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.layers) { layer in
                            LayerButton(
                                title: layer.name,
                                opacity: layer.opacity,
                                isSelected: viewModel.selectedLayerIDs.contains(layer.id),
                                isVisible: layer.isVisible,
                                onSelect: { shouldSelect in
                                    viewModel.selectLayer(id: layer.id, shouldSelect: shouldSelect)
                                },
                                onEyeToggle: { _ in
                                    viewModel.toggleVisibility(for: layer.id)
                                }
                            )
                        }
                    }
                    .padding()
                }
            } else {
                Spacer()
                Text("선택된 모델에 하위 레이어가 없습니다.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .onAppear {
            viewModel.reloadLayers()
        }
        .onChange(of: runtime.selectedEntity) {
            viewModel.reloadLayers()
        }
        .frame(width: 658, height: 522)
        .padding()
        .glassBackgroundEffect()
    }
}

