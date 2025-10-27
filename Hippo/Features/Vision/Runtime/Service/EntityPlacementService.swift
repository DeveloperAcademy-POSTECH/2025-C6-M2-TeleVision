//
//  EntityPlacementService.swift
//  Hippo
//
//  Created by yunsly on 10/26/25.
//

import simd
import RealityKit

public protocol AnchorServicing {
    func attach(entityID: String, to anchor: AnchorEntity) async throws
    func detach(entity: Entity) async throws
}

struct EntityPlacementService: AnchorServicing {
    
    func placeAnchorInFront() -> AnchorEntity {
        let pos = HeadPose.instance.position
        var fwd = HeadPose.instance.forward
        
        let len2 = simd_length_squared(fwd)
        fwd /= sqrt(len2) // 정규화
        
        let up = SIMD3<Float>(0, 1, 0)
        let target = pos + fwd * 1.0 + up * (-0.5)
        
        return AnchorEntity(world: target)
    }
    
    func attach(entityID: String, to anchor: AnchorEntity) async throws {
        Task { @MainActor in
            if let entity = try? await Entity(named: entityID) {
                
                // 조명 제거
                if let lightEntity = entity.findEntity(named: "Light") {
                    lightEntity.removeFromParent()
                }
                
                // Gesture
                let bounds = entity.visualBounds(relativeTo: nil)
                let size   = bounds.extents
                let box = ShapeResource.generateBox(size: size)
                entity.components.set(CollisionComponent(shapes: [box]))
                var manipulationComponent = ManipulationComponent()
                manipulationComponent.releaseBehavior = .stay
                
                entity.components.set(
                    [manipulationComponent, InputTargetComponent()]
                )
                
                // Anchor 에 부착
                anchor.addChild(entity)
            }
        }
    }
    
    func detach(entity: Entity) async {
        entity.removeFromParent()
    }
}
