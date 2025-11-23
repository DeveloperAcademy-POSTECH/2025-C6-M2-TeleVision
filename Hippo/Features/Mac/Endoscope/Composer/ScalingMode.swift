//
//  ScalingMode.swift
//  Hippo
//
//  Resolution scaling modes for performance optimization
//

import Foundation

/// Resolution scaling mode for video composition
public enum ScalingMode: String, Codable, CaseIterable {
    case none = "None"
    case half = "1/2"
    case third = "1/3"
    case quarter = "1/4"
    case sixth = "1/6"
    case eighth = "1/8"

    /// Scale factor to apply (1.0 = no scaling, 0.5 = half resolution)
    public var scaleFactor: Double {
        switch self {
        case .none:
            return 1.0
        case .half:
            return 0.5
        case .third:
            return 1.0 / 3.0
        case .quarter:
            return 0.25
        case .sixth:
            return 1.0 / 6.0
        case .eighth:
            return 0.125
        }
    }

    public var displayName: String {
        switch self {
        case .none:
            return "Original"
        case .half:
            return "1/2 (Half)"
        case .third:
            return "1/3"
        case .quarter:
            return "1/4 (Quarter)"
        case .sixth:
            return "1/6"
        case .eighth:
            return "1/8"
        }
    }

    /// Estimated memory/CPU reduction percentage
    public var performanceGain: String {
        switch self {
        case .none:
            return "0%"
        case .half:
            return "~75%"
        case .third:
            return "~89%"
        case .quarter:
            return "~94%"
        case .sixth:
            return "~97%"
        case .eighth:
            return "~98%"
        }
    }
}
