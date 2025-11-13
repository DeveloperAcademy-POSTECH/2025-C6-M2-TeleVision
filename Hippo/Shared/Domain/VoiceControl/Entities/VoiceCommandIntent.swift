//
//  VoiceCommandIntent.swift
//  Hippo
//

import Foundation

/// Parsed voice command intent
public enum VoiceCommandIntent: Equatable, Sendable {
    /// Hide UI panel
    case hideUI

    /// Show UI panel
    case showUI

    /// Close current panel/window
    case closePanel

    /// Rotate 3D entity
    case rotateEntity(direction: RotationDirection, angle: Double)

    /// Show video only (hide all UI)
    case showVideoOnly

    /// Unrecognized command
    case unknown(rawText: String)
}

/// Direction for entity rotation
public enum RotationDirection: String, Equatable, Sendable {
    case left
    case right
    case up
    case down
}
