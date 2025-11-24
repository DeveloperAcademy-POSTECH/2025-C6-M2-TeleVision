//
//  VoiceCommandIntent.swift
//  Hippo
//

import Foundation

/// Type of feedback message for UI styling
public enum FeedbackType: Equatable, Sendable {
    case info      // Blue - general information
    case success   // Green - command executed successfully
    case error     // Red/Orange - error occurred
}

/// Parsed voice command intent
public enum VoiceCommandIntent: Equatable, Sendable {
    /// Close menu/control panel
    case closeMenu

    /// Open menu/control panel
    case openMenu

    /// Close video/endoscopic view
    case closeVideo

    /// Show video/endoscopic view
    case showVideo

    /// Rotate 3D entity
    case rotateEntity(direction: RotationDirection, angle: Double)

    /// Cancel/stop voice control
    case cancelVoiceControl

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
