//
//  View+VisionDependencies.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//

import SwiftUI

extension View {
    /// Vision 전용 의존성을 한 번에 주입하는 헬퍼 (순수 SwiftUI 버전)
    func withVisionDependencies(
        open: @escaping @Sendable () async -> Void,
        close: @escaping @Sendable () async -> Void
    ) -> some View {
        // 실제 구현체 조립
        let router = AppRouter(open: open, close: close)
        let immersive = ImmersiveCoordinator(router: router)
        let locator = RealityEntityLocator()
        let anchoring = RealityAnchorService()

        return self
            .environment(\.immersive, immersive)
            .environment(\.entityLocator, locator)
            .environment(\.anchorService, anchoring)
    }
}
