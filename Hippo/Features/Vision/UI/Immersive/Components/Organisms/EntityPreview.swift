//
//  EntityPreview.swift
//  HippoVision
//
//  Created by yunsly on 11/9/25.
//

import SwiftUI
import RealityKit

@Observable
final class EntityPreview {
    var previewEntity: Entity? = nil
    let placementService: EntityPlacementService = EntityPlacementService()
    
    @MainActor
    func loadEntity(from url: URL, anchor: AnchorEntity) async {
        // 기존 엔티티 정리
        previewEntity?.removeFromParent()
        previewEntity = nil
        
        do {
            let entity = try await Entity(contentsOf: url)
            
            let bounds = entity.visualBounds(relativeTo: nil)
            let extent = length(bounds.extents) // 대각선 길이
            let target: Float = 0.20 // 20cm 정도로 보이게
            let scaleFactor = (extent > 0) ? (target / extent) : 1.0
            entity.scale *= SIMD3<Float>(repeating: scaleFactor)
            
            entity.position = [0, 0, -0.6]
            
            anchor.addChild(entity)
            self.previewEntity = entity
        } catch {
            print("Failed to load entity for preview: \(error)")
        }
    }
}
