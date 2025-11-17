//
//  SBSComposerConfig.swift
//  Hippo
//
//  Configuration for SBS composition
//

import Foundation
import CoreGraphics

/// Configuration for Side-by-Side composer
public struct SBSComposerConfig {
    /// Composition mode (Full or Half SBS)
    public let mode: SBSMode

    /// Normalization policy for input frames
    public let policy: NormalizePolicy

    /// Color space for composition
    public let colorSpace: CGColorSpace?

    /// Resolution scaling mode for performance optimization
    public let scalingMode: ScalingMode

    /// Default configuration (Full SBS, Crop to match aspect, ITU-R BT.709, No scaling)
    public static let `default` = SBSComposerConfig(
        mode: .full1080,
        policy: .cropToMatchAspect,
        colorSpace: CGColorSpace(name: CGColorSpace.itur_709),
        scalingMode: .none
    )

    /// Half SBS configuration (for bandwidth saving)
    public static let halfSBS = SBSComposerConfig(
        mode: .half1080,
        policy: .cropToMatchAspect,
        colorSpace: CGColorSpace(name: CGColorSpace.itur_709),
        scalingMode: .none
    )

    public nonisolated init(
        mode: SBSMode,
        policy: NormalizePolicy,
        colorSpace: CGColorSpace?,
        scalingMode: ScalingMode = .none
    ) {
        self.mode = mode
        self.policy = policy
        self.colorSpace = colorSpace
        self.scalingMode = scalingMode
    }
}
