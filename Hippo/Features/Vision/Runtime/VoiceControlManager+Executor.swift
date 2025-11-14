//
//  VoiceControlManager+Executor.swift
//  Hippo
//
//  VoiceCommandExecutor implementation for VoiceControlManager
//

import Foundation

// MARK: - VoiceCommandExecutor

extension VoiceControlManager: VoiceCommandExecutor {

    /// Execute voice command intent
    ///
    /// Maps voice command intents to concrete actions:
    /// - Menu control (open/close)
    /// - Video control (show/hide endoscope)
    /// - Entity manipulation (rotate)
    ///
    /// - Parameter intent: The command intent to execute
    /// - Throws: VoiceControlError if execution fails
    public func execute(_ intent: VoiceCommandIntent) async throws {
        switch intent {
        case .closeMenu:
            closeHeadController()

        case .openMenu:
            openHeadController()

        case .closeVideo:
            closeEndoscopicView()

        case .showVideo:
            openEndoscopicView()

        case let .rotateEntity(direction, angle):
            try await runtime.rotateSelectedEntity(direction: direction, angle: angle)

        case .unknown:
            throw VoiceControlError.noIntent
        }
    }
}
