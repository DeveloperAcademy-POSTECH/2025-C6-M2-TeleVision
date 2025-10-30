

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
        anchor2.position = [0, -0.6, -1.0] // 시야 아래쪽에 배치
        if let bottomMenuBar = attachments.entity(for: AttachmentIDs.bottomMenuBar) {
            anchor2.addChild(bottomMenuBar)
        }

        let anchor3 = AnchorEntity(.head)
        anchor3.position = [0, 0, -1.0]
        if let finishAlert = attachments.entity(for: AttachmentIDs.finishSurgeryAlert) {
            anchor3.addChild(finishAlert)
        }

        content.add(anchor1)
        content.add(anchor2)
        content.add(anchor3)

        topAnchor = anchor1
        bottomAnchor = anchor2
        finishAlertAnchor = anchor3

        // 마지막 조작 Entity 정보 저장
        eventSubscription = content.subscribe(to: ManipulationEvents.WillBegin.self)  { event in
            self.selectedEntity? = event.entity
        }
    }

    func start() {
        logger.debug("🐛 ImmersiveSceneRuntime started")

        // TODO: 추후 Entity 조작모드가 on 될 때만 작동하도록 수정할 것
        ARSessionController.shared.runARSession()
    }

    func stop() {
        logger.debug("🐛 ImmersiveSceneRuntime stopped")
        topAnchor = nil
        bottomAnchor = nil
        finishAlertAnchor = nil

         // TODO: 추후 Entity 조작모드 off 될 때만 작동하도록 수정할 것
        ARSessionController.shared.stopARSession()
        
        // 제스쳐 이벤트 구독 정리
        eventSubscription?.cancel()
    }
}
