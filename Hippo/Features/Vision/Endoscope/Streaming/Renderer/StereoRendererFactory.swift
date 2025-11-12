//
//  StereoRendererFactory.swift
//  Hippo
//
//  Factory for creating appropriate stereo renderer
//  Encapsulates all platform/version checks
//

import Foundation

/// Factory for creating stereo renderers
/// Hides all conditional compilation behind clean API
@MainActor
public enum StereoRendererFactory {

    /// Create the best available stereo renderer for current platform
    /// - Returns: CompositorStereoRenderer on visionOS 2.0+, nil otherwise
    public static func createCompositorRenderer() -> (any StereoRendering)? {
        if #available(visionOS 2.0, *) {
            return CompositorStereoRenderer()
        }
        return nil
    }

    /// Create legacy RealityKit renderer (always available on visionOS)
    public static func createRealityKitRenderer() -> any StereoRendering {
        return StereoVideoRenderer()
    }
}
