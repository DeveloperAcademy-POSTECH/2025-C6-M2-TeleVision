

import os.log
import RealityKit
import SwiftUI
import Foundation

@MainActor
@Observable
final class ImmersiveSceneRuntime {
    // MARK: - Logger
    
    private let logger = Logger(subsystem: "com.television.hippo", category: "ImmersiveSceneRuntime")
    
    public init() {}
    
    // MARK: - State
    
    private var topAnchor: AnchorEntity?
    
    
    //MARK: - 3D model 들이 추가될 루트 엔티티
    var sceneRoot: Entity?
    
    // MARK: - Setup
    
    var selectedEntity: Entity? = nil
    private var eventSubscription: EventSubscription? = nil
    
    private let placementService: EntityPlacementService = EntityPlacementService()
    
    // RealityView 의 content 관리
    func setupScene(in content: RealityViewContent, attachments: RealityViewAttachments) {
        let anchor1 = AnchorEntity(.head)
        anchor1.position = [0, 0.25, -1.0]
        if let topButton = attachments.entity(for: AttachmentIDs.topToggleButton) {
            anchor1.addChild(topButton)
        }
        
        content.add(anchor1)
        
        topAnchor = anchor1
        
        // 3D 모델들의 월드 앵커의 부모
        let rootEntity = Entity()
        rootEntity.name = "SceneRoot"
        content.add(rootEntity)
        self.sceneRoot = rootEntity
        
        // 마지막 조작 Entity 정보 저장
        eventSubscription = content.subscribe(to: ManipulationEvents.WillBegin.self)  { event in
            if let previousSelection = self.selectedEntity {
                previousSelection.name = ""
            }
            event.entity.name = "selected"
            self.selectedEntity = event.entity
        }
    }
    
    func placeEntity(url: URL) async {
        guard let sceneRoot = self.sceneRoot else {
            logger.error("Scene root is not yet set up.")
            return
        }
        
        let anchor = placementService.placeAnchorInFront()
        sceneRoot.addChild(anchor)
        
        do {
            selectedEntity = try await placementService.attach(url: url, to: anchor)
            logger.debug("Entity from URL '\(url.lastPathComponent)' placed successfully.")
        } catch {
            logger.error("Failed to attach entity from URL: \(error)")
            // 실패 시 생성했던 앵커 정리
            anchor.removeFromParent()
        }
    }
    
    func deleteSelectedEntity() async {
        guard let entity = selectedEntity else {
            logger.warning("Delete requested, but no entity is selected.")
            return
        }
        
        await placementService.detach(entity: entity)
        self.selectedEntity = nil
        
        logger.debug("Selected entity deleted and selection cleared.")
    }
    
    func start() {
        logger.debug("🐛 ImmersiveSceneRuntime started")
        ARSessionController.shared.runARSession()
    }
    
    func stop() {
        logger.debug("🐛 ImmersiveSceneRuntime stopped")
        topAnchor = nil
        
        // 제스쳐 이벤트 구독 정리
        eventSubscription?.cancel()
    }
}
