

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
    private var finishAlertAnchor: AnchorEntity?
    private var assetListAnchor: AnchorEntity?
    private var opacityPanelAnchor: AnchorEntity?
    private var endoscopeStreamAnchor: AnchorEntity?  // 내시경 스트리밍
    
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
        anchor2.position = [0, -0.27, -0.45] // 시야 아래쪽에 배치
        if let bottomMenuBar = attachments.entity(for: AttachmentIDs.bottomMenuBar) {
            // 회전
            let pitchUp = simd_quatf(angle: -(20 * .pi / 180), axis: [1, 0, 0])
            bottomMenuBar.setOrientation(pitchUp, relativeTo: anchor2)
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
        
        let anchor5 = AnchorEntity(.head)
        anchor5.position = [0.2, 0, -1.0] // 예시 위치 (오른쪽)
        if let opacityPanel = attachments.entity(for: AttachmentIDs.opacityControlPanel) {
            anchor5.addChild(opacityPanel)
        }

        // 내시경 스트리밍 뷰 (중앙 전면)
        let anchor6 = AnchorEntity(.head)
        anchor6.position = [0, 0, -0.8]  // 중앙, 80cm 전방
        if let endoscopeStream = attachments.entity(for: AttachmentIDs.endoscopeStream) {
            anchor6.addChild(endoscopeStream)
        }

        content.add(anchor1)
        content.add(anchor2)
        content.add(anchor3)
        content.add(anchor4)
        content.add(anchor5)
        content.add(anchor6)

        topAnchor = anchor1
        bottomAnchor = anchor2
        finishAlertAnchor = anchor3
        assetListAnchor = anchor4
        opacityPanelAnchor = anchor5
        endoscopeStreamAnchor = anchor6
        
        // 3D 모델들의 월드 앵커의 부모
        let rootEntity = Entity()
        rootEntity.name = "SceneRoot"
        content.add(rootEntity)
        self.sceneRoot = rootEntity
        
        // Attachment View 앵커 비활성화
        self.assetListAnchor?.isEnabled = false
        self.finishAlertAnchor?.isEnabled = false
        self.opacityPanelAnchor?.isEnabled = false
        self.endoscopeStreamAnchor?.isEnabled = false  // 초기에는 비활성화
        
        // 마지막 조작 Entity 정보 저장
        eventSubscription = content.subscribe(to: ManipulationEvents.WillBegin.self)  { event in
            self.selectedEntity = event.entity
        }
    }
    
    func setFinishAlertVisibility(isVisible: Bool) {
        self.finishAlertAnchor?.isEnabled = isVisible
        logger.debug("FinishAlert Anchor 'isEnabled' set to: \(isVisible)")
        
    }
    
    func setAssetListVisibility(isVisible: Bool) {
        self.assetListAnchor?.isEnabled = isVisible
        logger.debug("Asset List Anchor 'isEnabled' set to: \(isVisible)")
        
    }
    
    func setOpacityPanelVisibility(isVisible: Bool) {
        self.opacityPanelAnchor?.isEnabled = isVisible
        logger.debug("OpacityPanel Anchor 'isEnabled' set to: \(isVisible)")
    }

    func setEndoscopeStreamVisibility(isVisible: Bool) {
        self.endoscopeStreamAnchor?.isEnabled = isVisible
        logger.debug("EndoscopeStream Anchor 'isEnabled' set to: \(isVisible)")
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
        finishAlertAnchor = nil
        assetListAnchor = nil
        opacityPanelAnchor = nil
        
        // 제스쳐 이벤트 구독 정리
        eventSubscription?.cancel()
    }
}
