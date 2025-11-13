//
//  VoiceCommandParser.swift
//  Hippo
//

import Foundation

/// Domain service for parsing voice commands into intents
///
/// Implementations can use rule-based parsing or LLM-based parsing.
/// The interface remains the same regardless of implementation strategy.
public protocol VoiceCommandParser: Sendable {
    /// Parse STT text into a voice command intent
    ///
    /// - Parameter text: Recognized speech text from STT
    /// - Returns: Parsed voice command intent
    /// - Throws:
    ///   - `VoiceControlError.noIntent`: No recognizable intent found
    ///   - `VoiceControlError.invalidParameters`: Command parameters are invalid
    ///   - `VoiceControlError.parsingFailed`: Parsing logic failed (e.g., LLM API error)
    func parse(text: String) async throws -> VoiceCommandIntent
}
