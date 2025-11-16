//
//  SpeechRecognitionService.swift
//  Hippo
//

import Foundation

/// Domain service for speech recognition (STT)
///
/// This service is designed for single utterance recognition,
/// where the system listens for one complete command and returns the result.
public protocol SpeechRecognitionService: Sendable {
    /// Recognize a single utterance and return the transcribed text
    ///
    /// This method:
    /// 1. Starts listening
    /// 2. Waits for a complete utterance (sentence)
    /// 3. Returns the transcribed text
    /// 4. Automatically stops listening
    ///
    /// - Returns: Transcribed text from the utterance
    /// - Throws:
    ///   - `VoiceControlError.speechRecognitionFailed`: STT engine error
    ///   - `VoiceControlError.permissionDenied`: Microphone permission not granted
    func recognizeSingleUtterance() async throws -> String
}
