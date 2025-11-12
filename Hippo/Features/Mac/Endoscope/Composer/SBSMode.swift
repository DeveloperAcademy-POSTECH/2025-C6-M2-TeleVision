//
//  SBSMode.swift
//  Hippo
//
//  Side-by-Side composition modes
//

import Foundation
import CoreGraphics

/// SBS composition mode
public enum SBSMode: String, Codable, CaseIterable {
    case full1080  = "full1080"   // 3840×1080 (1920×1080 per eye)
    case half1080  = "half1080"   // 1920×540 (960×540 per eye)

    /// Output resolution for composed SBS frame
    public var outputSize: CGSize {
        switch self {
        case .full1080:
            return CGSize(width: 3840, height: 1080)
        case .half1080:
            return CGSize(width: 1920, height: 540)
        }
    }

    /// Single eye resolution
    public var eyeSize: CGSize {
        switch self {
        case .full1080:
            return CGSize(width: 1920, height: 1080)
        case .half1080:
            return CGSize(width: 960, height: 540)
        }
    }

    public var displayName: String {
        switch self {
        case .full1080:
            return "Full SBS (3840×1080)"
        case .half1080:
            return "Half SBS (1920×540)"
        }
    }
}
