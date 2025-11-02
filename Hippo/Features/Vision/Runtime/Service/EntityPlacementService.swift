//
//  EntityPlacementService.swift
//  Hippo
//
//  Created by yunsly on 10/26/25.
//

import simd
import RealityKit
import Foundation

public protocol AnchorServicing {
    func attach(url: URL,to anchor: AnchorEntity) async throws
    func detach(entity: Entity) async throws
}

struct EntityPlacementService: AnchorServicing {
    
    func placeAnchorInFront() -> AnchorEntity {
        let pos = HeadPose.instance.position
        var fwd = HeadPose.instance.forward
        
        let len2 = simd_length_squared(fwd)
        fwd /= sqrt(len2) // 정규화
        
        let up = SIMD3<Float>(0, 1, 0)
        let target = pos + fwd * 1.0 + up * (0.03)
        
        return AnchorEntity(world: target)
    }
    
    @MainActor
    func attach(url: URL, to anchor: AnchorEntity) async throws {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let entity = try await Entity(contentsOf: url)
        
        // 조명 제거
        if let lightEntity = entity.findEntity(named: "Light") {
            lightEntity.removeFromParent()
        }
        
        anchor.addChild(entity)
        
        entity.scale = SIMD3<Float>(repeating: 0.003)
        
        // Gesture
        let bounds = entity.visualBounds(relativeTo: entity)
        let size   = bounds.extents
        let box = ShapeResource.generateBox(size: size)
        entity.components.set(CollisionComponent(shapes: [box]))
        var manipulationComponent = ManipulationComponent()
        manipulationComponent.releaseBehavior = .stay
        
        entity.components.set(
            [manipulationComponent, InputTargetComponent()]
        )
        
        
        
        
    }
    
    func detach(entity: Entity) async {
        entity.removeFromParent()
    }
}
