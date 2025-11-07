//
//  NormalizePolicy.swift
//  Hippo
//
//  Frame normalization policy for SBS composition
//

import Foundation

/// Policy for normalizing input frames to target size
public enum NormalizePolicy: String, Codable, CaseIterable {
    /// Crop to match aspect ratio, then scale to target
    /// Recommended for most use cases
    case cropToMatchAspect = "cropToMatchAspect"

    /// Scale down only (never upscale)
    /// Preserves original quality when source is larger
    case scaleDownOnly = "scaleDownOnly"

    /// Allow upscaling if needed
    /// May reduce quality for smaller sources
    case allowUpscale = "allowUpscale"

    public var displayName: String {
        switch self {
        case .cropToMatchAspect:
            return "Crop to Match Aspect"
        case .scaleDownOnly:
            return "Scale Down Only"
        case .allowUpscale:
            return "Allow Upscale"
        }
    }

    public var description: String {
        switch self {
        case .cropToMatchAspect:
            return "Crops frames to 16:9, then scales to target size. Best quality."
        case .scaleDownOnly:
            return "Only scales down if source is larger. Never upscales."
        case .allowUpscale:
            return "Scales to target size even if it means upscaling."
        }
    }
}
