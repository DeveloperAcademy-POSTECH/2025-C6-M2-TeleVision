

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

    // MARK: - Setup

    // RealityView 의 content 관리
    func setupScene(in content: RealityViewContent, attachments: RealityViewAttachments) {
        let anchor1 = AnchorEntity(.head)
        anchor1.position = [0, 0.45, -1.0]
        if let topButton = attachments.entity(for: AttachmentIDs.topToggleButton) {
            anchor1.addChild(topButton)
        }

        let anchor2 = AnchorEntity(.head)
        anchor2.position = [0, -0.45, -1.0] // 시야 아래쪽에 배치
        if let bottomMenuBar = attachments.entity(for: AttachmentIDs.bottomMenuBar) {
            anchor2.addChild(bottomMenuBar)
        }

        content.add(anchor1)
        content.add(anchor2)

        topAnchor = anchor1
        bottomAnchor = anchor2
    }

    func start() {
        logger.debug("🐛 ImmersiveSceneRuntime started")
    }

    func stop() {
        logger.debug("🐛 ImmersiveSceneRuntime stopped")
        topAnchor = nil
    }
}
