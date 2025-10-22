//
//  View+VisionDependencies.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//

import SwiftUI

// Note: ImmersiveSpace 진입/종료는 Apple 제공 Environment를 직접 사용
// @Environment(\.openImmersiveSpace)
// @Environment(\.dismissImmersiveSpace)
//
// 이 파일은 RealityKit 관련 서비스만 주입하기 위해 유지됩니다.

extension View {
    /// RealityKit 전용 의존성을 한 번에 주입하는 헬퍼
    func withRealityKitDependencies(
        entityLocator: EntityLocating = RealityEntityLocator(),
        anchorService: AnchorServicing = RealityAnchorService()
    ) -> some View {
        self
            .environment(\.entityLocator, entityLocator)
            .environment(\.anchorService, anchorService)
    }
}
