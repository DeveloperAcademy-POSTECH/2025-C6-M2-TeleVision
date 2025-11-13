//
//  StereoRendererProtocol.swift
//  Hippo
//
//  Stereo renderer abstraction to avoid conditional compilation mess
//

import Foundation
import CoreVideo

/// Protocol for stereo video renderers
/// Hides implementation details (RealityKit vs CompositorServices)
@MainActor
public protocol StereoRendering: AnyObject {
    /// Update frame with new pixel buffer
    func updateFrame(_ pixelBuffer: CVPixelBuffer)

    /// Check if renderer is ready
    var isReady: Bool { get }
}

// MARK: - Make existing renderers conform

extension StereoVideoRenderer: StereoRendering {
    // Already has updateFrame and isReady
}

@available(visionOS 2.0, *)
extension CompositorStereoRenderer: StereoRendering {
    // Already has updateFrame and isReady
}
