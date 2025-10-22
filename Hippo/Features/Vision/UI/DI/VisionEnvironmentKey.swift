//
//  VisionEnvironmentKey.swift
//  Hippo
//
//  Created by eunsong on 10/22/25.
//
import SwiftUI

// MARK: - Environment Keys

private struct ImmersiveKey: EnvironmentKey {
    static let defaultValue: ImmersiveControlling? = nil
}

private struct EntityLocatorKey: EnvironmentKey {
    static let defaultValue: EntityLocating? = nil
}

private struct AnchorServiceKey: EnvironmentKey {
    static let defaultValue: AnchorServicing? = nil
}

// MARK: - Environment Values

extension EnvironmentValues {
    var immersive: ImmersiveControlling? {
        get { self[ImmersiveKey.self] }
        set { self[ImmersiveKey.self] = newValue }
    }
    var entityLocator: EntityLocating? {
        get { self[EntityLocatorKey.self] }
        set { self[EntityLocatorKey.self] = newValue }
    }
    var anchorService: AnchorServicing? {
        get { self[AnchorServiceKey.self] }
        set { self[AnchorServiceKey.self] = newValue }
    }
}
