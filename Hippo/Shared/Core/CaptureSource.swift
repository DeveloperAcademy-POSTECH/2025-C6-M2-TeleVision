//
//  CaptureSource.swift
//  Hippo
//
//  Defines capture source (left/right camera)
//

import Foundation

/// Camera source identifier for stereo capture
public enum CaptureSource: String, Codable, CaseIterable {
    case left = "left"
    case right = "right"

    public var displayName: String {
        switch self {
        case .left: return "Left Camera"
        case .right: return "Right Camera"
        }
    }
}
