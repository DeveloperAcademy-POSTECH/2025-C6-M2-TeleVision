//
//  VoiceControlState.swift
//  Hippo
//

import Foundation

/// Voice control system state
///
/// State transitions: Idle → Standby (hover) → Listening (wake word) → Idle (success) or Retry (failure)
public enum VoiceControlState: Equatable, Sendable {
    /// Default state, no voice control active
    case idle

    /// Hovering over voice control button, waiting for wake word "Hippo"
    case standby

    /// Actively recognizing a single voice command
    case listening

    /// Command failed, auto-retrying within deadline
    case retry(attempt: Int, deadline: Date)

    /// Whether the system is actively listening
    public var isActive: Bool {
        switch self {
        case .listening, .retry:
            return true
        case .idle, .standby:
            return false
        }
    }
}
