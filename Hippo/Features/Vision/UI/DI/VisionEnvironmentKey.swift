//
//  VisionEnvironmentKey.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//
import SwiftUI

// MARK: - RealityKit Environment Keys

// Note: ImmersiveSpace 진입/종료는 Apple 제공 Environment를 직접 사용
// @Environment(\.openImmersiveSpace)
// @Environment(\.dismissImmersiveSpace)

private struct AnchorServiceKey: EnvironmentKey {
    static let defaultValue: AnchorServicing? = nil
}

// MARK: - Environment Values

extension EnvironmentValues {
    var anchorService: AnchorServicing? {
        get { self[AnchorServiceKey.self] }
        set { self[AnchorServiceKey.self] = newValue }
    }
}
