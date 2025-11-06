

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
    private var bottomAnchor: AnchorEntity?
    private var assetListAnchor: AnchorEntity?

    
    //MARK: - 3D model 들이 추가될 루트 엔티티
    private var sceneRoot: Entity?
    
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
        
        let anchor2 = AnchorEntity(.head)
        anchor2.position = [0, -0.1, -0.45] // 시야 아래쪽에 배치
        if let bottomMenuBar = attachments.entity(for: AttachmentIDs.bottomMenuBar) {
            // 회전
            let pitchUp = simd_quatf(angle: -(20 * .pi / 180), axis: [1, 0, 0])
            bottomMenuBar.setOrientation(pitchUp, relativeTo: anchor2)
            anchor2.addChild(bottomMenuBar)
        }
        
        let anchor3 = AnchorEntity(.head)
        anchor3.position = [0, -0.15, -1.0]
        if let assetList = attachments.entity(for: AttachmentIDs.assetListView) {
            anchor3.addChild(assetList)
        }

        
        content.add(anchor1)
        content.add(anchor2)
        content.add(anchor3)
        
        topAnchor = anchor1
        bottomAnchor = anchor2
        assetListAnchor = anchor3
        
        // 3D 모델들의 월드 앵커의 부모
        let rootEntity = Entity()
        rootEntity.name = "SceneRoot"
        content.add(rootEntity)
        self.sceneRoot = rootEntity
        
        // Attachment View 앵커 비활성화
        self.assetListAnchor?.isEnabled = false
        
        // 마지막 조작 Entity 정보 저장
        eventSubscription = content.subscribe(to: ManipulationEvents.WillBegin.self)  { event in
            self.selectedEntity = event.entity
        }
    }
    
    func setAssetListVisibility(isVisible: Bool) {
        self.assetListAnchor?.isEnabled = isVisible
        logger.debug("Asset List Anchor 'isEnabled' set to: \(isVisible)")
    }
    
    func placeEntity(url: URL) async {
        guard let sceneRoot = self.sceneRoot else {
            logger.error("Scene root is not yet set up.")
            return
        }
        
        let anchor = placementService.placeAnchorInFront()
        sceneRoot.addChild(anchor)
        
        do {
            try await placementService.attach(url: url, to: anchor)
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
        bottomAnchor = nil
        assetListAnchor = nil
        
        // 제스쳐 이벤트 구독 정리
        eventSubscription?.cancel()
    }
}
