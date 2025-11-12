//
//  OpacityControlPanel.swift
//  Hippo
//
//  Created by yunsly on 11/1/25.
//

import SwiftUI
import RealityKit

struct OpacityControlPanel: View {
    
    @Environment(OpacityManager.self) var opacityManager: OpacityManager
    @Environment(ImmersiveSceneRuntime.self) var runtime: ImmersiveSceneRuntime
    
    // Grid 레이아웃 설정 (4열)
    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        @Bindable var manager = opacityManager
        
        VStack {
            OpacityControlPanelHeader(
                isAllSelected: manager.isAllSelected,
                isAllVisible: manager.isAllVisible,
                onDeleteTapped: {
                    Task {
                        await runtime.deleteSelectedEntity()
                    }
                },
                onSelectAllToggle: { shouldSelectAll in
                    manager.selectAllLayers(shouldSelectAll: shouldSelectAll)
                },
                onShowAllToggle: {_ in
                    manager.setVisibilityForAll(to: !manager.isAllVisible)
                }
            )
            
            // 투명도 슬라이더
            OpacityControlSlider(
                currentOpacity: $manager.currentOpacity,
                selectedLayerIDS: manager.selectedLayerIDs,
                isMixed: manager.isMixed
            )
            Spacer(minLength: 16)
            
            // 2. 레이어 버튼 그리드
            if manager.hasAnyLayers {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(manager.layers) { layer in
                            LayerButton(
                                title: layer.name,
                                opacity: layer.opacity,
                                isSelected: manager.selectedLayerIDs.contains(layer.id),
                                isVisible: layer.isVisible,
                                onSelect: { shouldSelect in
                                    manager.selectLayer(id: layer.id, shouldSelect: shouldSelect)
                                },
                                onEyeToggle: { _ in
                                    manager.toggleVisibility(for: layer.id)
                                }
                            )
                        }
                    }
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
            manager.reloadLayers()
        }
        .onChange(of: runtime.selectedEntity) {
            manager.reloadLayers()
            opacityManager.setOpacityForUnselctedEntity(needsToShow: true)
        }
        .padding(24)
        .onDisappear {
            runtime.selectedEntity = nil
            manager.setOpacityForUnselctedEntity(needsToShow: false)
        }
    }
}

