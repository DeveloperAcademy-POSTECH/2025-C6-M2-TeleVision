//
//  OpacityControlPanel.swift
//  Hippo
//
//  Created by yunsly on 11/1/25.
//

import SwiftUI
import RealityKit

struct OpacityControlPanel: View {
    
    var viewModel: OpacityControlViewModel
    
    @State private var selectedLayerIDs: Set<String> = []
    
    // Grid 레이아웃 설정 (3열)
    private let columns: [GridItem] = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    private var isAllSelected: Bool {
        !viewModel.layers.isEmpty && selectedLayerIDs.count == viewModel.layers.count
    }
    
    var body: some View {
        VStack {
            OpacityControlPanelHeader(
                isAllSelected: isAllSelected,
                isAllVisible: viewModel.isAllVisible,
                onDeleteTapped: {
                    viewModel.deleteSelectedEntity()
                },
                onSelectAllToggle: { shouldSelectAll in
                    if shouldSelectAll {
                        selectedLayerIDs = Set(viewModel.layers.map { $0.id })
                    } else {
                        selectedLayerIDs.removeAll()
                    }
                },
                onShowAllToggle: {_ in
                    viewModel.setVisibilityForAll(to: !viewModel.isAllVisible)
                }
            )
            
            // TODO: 투명도 슬라이더 (요청대로 일단 보류)
            
            // 2. 레이어 버튼 그리드
            if viewModel.hasAnyLayers {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(viewModel.layers) { layer in
                            LayerButton(
                                title: layer.name,
                                opacity: layer.opacity,
                                isSelected: selectedLayerIDs.contains(layer.id),
                                isVisible: layer.isVisible,
                                onSelect: { shouldSelect in
                                    if shouldSelect {
                                        selectedLayerIDs.insert(layer.id)
                                    } else {
                                        selectedLayerIDs.remove(layer.id)
                                    }
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
        .onChange(of: viewModel.runtime.selectedEntity) {
            viewModel.reloadLayers()
            selectedLayerIDs.removeAll() // 선택 상태 초기화
        }
        .frame(width: 500, height: 522)
        .padding()
        .glassBackgroundEffect()
    }
}

