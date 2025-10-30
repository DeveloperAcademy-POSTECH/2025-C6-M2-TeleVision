

import os.log
import RealityKit
import SwiftUI

@MainActor
@Observable
final class ImmersiveSceneRuntime {
    // MARK: - Logger

    private let logger = Logger(subsystem: "com.television.hippo", category: "ImmersiveSceneRuntime")

    public init() {}

    // MARK: - State

    private var topAnchor: AnchorEntity?
    private var bottomAnchor: AnchorEntity?
    private var finishAlertAnchor: AnchorEntity?
    private var assetListAnchor: AnchorEntity?
    
    //MARK: - 3D model 들이 추가될 루트 엔티티
    private var sceneRoot: Entity?

    // MARK: - Setup
    
    var selectedEntity: Entity? = nil
    private var eventSubscription: EventSubscription? = nil

    // RealityView 의 content 관리
    func setupScene(in content: RealityViewContent, attachments: RealityViewAttachments) {
        let anchor1 = AnchorEntity(.head)
        anchor1.position = [0, 0.3, -1.0]
        if let topButton = attachments.entity(for: AttachmentIDs.topToggleButton) {
            anchor1.addChild(topButton)
        }

        let anchor2 = AnchorEntity(.head)
        anchor2.position = [0, -0.5, -1.0] // 시야 아래쪽에 배치
        if let bottomMenuBar = attachments.entity(for: AttachmentIDs.bottomMenuBar) {
            anchor2.addChild(bottomMenuBar)
        }

        let anchor3 = AnchorEntity(.head)
        anchor3.position = [0, 0, -1.0]
        if let finishAlert = attachments.entity(for: AttachmentIDs.finishSurgeryAlert) {
            anchor3.addChild(finishAlert)
        }
        
        let anchor4 = AnchorEntity(.head)
        anchor4.position = [0, -0.15, -1.0]
        if let assetList = attachments.entity(for: AttachmentIDs.assetListView) {
            anchor4.addChild(assetList)
        }
        
        content.add(anchor1)
        content.add(anchor2)
        content.add(anchor3)
        content.add(anchor4)

        topAnchor = anchor1
        bottomAnchor = anchor2
        finishAlertAnchor = anchor3
        assetListAnchor = anchor4
        
        // 3D 모델들의 월드 앵커의 부모
        let rootEntity = Entity()
        rootEntity.name = "SceneRoot"
        content.add(rootEntity)
        self.sceneRoot = rootEntity
        
        // Attachment View 앵커 비활성화
        self.assetListAnchor?.isEnabled = false
        self.finishAlertAnchor?.isEnabled = false
        
        
        // 마지막 조작 Entity 정보 저장
        eventSubscription = content.subscribe(to: ManipulationEvents.WillBegin.self)  { event in
            self.selectedEntity? = event.entity
        }

    }
    
    func setFinishAlertVisibility(isVisible: Bool) {
        self.finishAlertAnchor?.isEnabled = isVisible
        logger.debug("FinishAlert Anchor isEnabled' set to: \(isVisible)")

    }
    
    func setAssetListVisibility(isVisible: Bool) {
        self.assetListAnchor?.isEnabled = isVisible
        logger.debug("Asset List Anchor 'isEnabled' set to: \(isVisible)")

    }
    
    func placeEntity(entityID: String, service: EntityPlacementService) async {
            guard let sceneRoot = self.sceneRoot else {
                logger.error("Scene root is not yet set up.")
                return
            }
            
            let anchor = service.placeAnchorInFront()
            sceneRoot.addChild(anchor)

            do {
                try await service.attach(entityID: entityID, to: anchor)
                logger.debug("Entity '\(entityID)' placed successfully.")
            } catch {
                logger.error("Failed to attach entity '\(entityID)': \(error)")
                // 실패 시 생성했던 앵커 정리
                anchor.removeFromParent()
            }
        }

    func start() {
        logger.debug("🐛 ImmersiveSceneRuntime started")
        ARSessionController.shared.runARSession()
    }

    func stop() {
        logger.debug("🐛 ImmersiveSceneRuntime stopped")
        topAnchor = nil
        bottomAnchor = nil
        finishAlertAnchor = nil
        assetListAnchor = nil
        
        // 제스쳐 이벤트 구독 정리
        eventSubscription?.cancel()
    }
}
