//
//  VoiceCommandExecutor.swift
//  Hippo
//

import Foundation

/// Domain service for executing voice command intents
///
/// Implementation will be provided by Presentation layer (e.g., ViewModel)
/// to perform actual UI/3D entity manipulations.
public protocol VoiceCommandExecutor: Sendable {
    /// Execute a voice command intent
    ///
    /// - Parameter intent: The parsed voice command intent to execute
    /// - Throws: VoiceControlError if execution fails
    func execute(_ intent: VoiceCommandIntent) async throws
}
