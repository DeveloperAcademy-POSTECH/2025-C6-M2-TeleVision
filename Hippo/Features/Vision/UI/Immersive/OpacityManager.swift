//
//  OpacityManager.swift
//  Hippo
//
//  Created by yunsly on 10/27/25.
//

import RealityKit
import SwiftUI
import Combine

@Observable
final class OpacityManager {
    
    struct Layer: Identifiable {
        let id: String
        let name: String
        let entity: Entity
        var isVisible: Bool
        var opacity: Float
    }
    
    var layers: [Layer] = []
    var runtime: ImmersiveSceneRuntime
    
    var isAllVisible: Bool {
        guard !layers.isEmpty else { return false }
        return layers.allSatisfy { $0.isVisible }
    }
    
    var hasAnyLayers: Bool {
        !layers.isEmpty
    }
    
    // Opacity 조절용 변수
    var selectedLayerIDs: Set<String> = []
    var currentOpacity: Float {
        get {
            guard let firstSelectedID = selectedLayerIDs.first,
                  let layer = layers.first(where: { $0.id == firstSelectedID }) else {
                return 1.0
            }
            return layer.opacity
        }
        set {
            setOpacity(for: Array(selectedLayerIDs), opacity: newValue)
        }
    }
    
    var isAllSelected: Bool {
        !layers.isEmpty && selectedLayerIDs.count == layers.count
    }
    
    var isMixed: Bool {
        let selectedLayers = layers.filter { selectedLayerIDs.contains($0.id) }
        guard selectedLayers.count > 1 else {
            return false
        }
        
        let uniqueOpacities = Set(selectedLayers.map { $0.opacity })
        return uniqueOpacities.count > 1
    }
    
    init(runtime: ImmersiveSceneRuntime) {
        self.runtime = runtime
    }
    
    // MARK: -- Layer 탐색
    
    // Panel 에서 호출: selectedEntity 가 변경될 때마다 갱신
    func reloadLayers() {
        guard let entity = runtime.selectedEntity else {
            layers = []
            return
        }
        
        let leafNodes = collectLeafNodes(from: entity)
        layers = leafNodes.enumerated().map { idx, e in
            let currentOpacity = e.components[OpacityComponent.self]?.opacity ?? 1.0
            
            return Layer(id: Self.layerID(for: e),
                         name: e.name.isEmpty ? "Layer \(idx + 1)" : e.name,
                         entity: e,
                         isVisible: e.isEnabled,
                         opacity: currentOpacity)
        }
        selectedLayerIDs.removeAll()
    }
    
    private func collectLeafNodes(from entity: Entity) -> [Entity] {
        if entity.children.isEmpty {
            return (entity.components[ModelComponent.self] != nil) ? [entity] : []
        }
        return entity.children.flatMap { collectLeafNodes(from: $0) }
    }
    
    private static func layerID(for entity: Entity) -> String {
        var chain: [String] = []
        var current: Entity? = entity
        while let e = current {
            chain.append(e.name)
            current = e.parent
        }
        let path = chain.reversed().joined(separator: "/")
        return String(path.hashValue)
    }
    
    
    // MARK: -- 선택된 Layer 들의 visibility / Opacity 조정
    
    // 선택 상태 관리
    func selectLayer(id: String, shouldSelect: Bool) {
        if shouldSelect {
            selectedLayerIDs.insert(id)
        } else {
            selectedLayerIDs.remove(id)
        }
    }
    
    func selectAllLayers(shouldSelectAll: Bool) {
        if shouldSelectAll {
            selectedLayerIDs = Set(layers.map { $0.id })
        } else {
            selectedLayerIDs.removeAll()
        }
    }
    
    // 선택된 layer 의 visibility 설정
    func toggleVisibility(for partID: Layer.ID) {
        guard let index = layers.firstIndex(where: { $0.id == partID }) else { return }
        
        let newVisibility = !layers[index].isVisible
        layers[index].isVisible = newVisibility
        layers[index].entity.isEnabled = newVisibility
    }
    
    // 선택된 layer들의 Opacity 조정
    func setOpacity(for partIDs: [Layer.ID], opacity: Float) {
        for partID in partIDs {
            guard let index = layers.firstIndex(where: { $0.id == partID }) else { continue }
            
            layers[index].opacity = opacity
            let opacityComponent = OpacityComponent(opacity: opacity)
            layers[index].entity.components.set(opacityComponent)
        }
    }
    
    // MARK: -- 전체 Layer
    func setVisibilityForAll(to isVisible: Bool) {
        for index in layers.indices {
            layers[index].isVisible = isVisible
            layers[index].entity.isEnabled = isVisible
        }
    }
}
