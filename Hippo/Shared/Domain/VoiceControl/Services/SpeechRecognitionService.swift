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

    /// Fast wake word detection (optimized for quick response)
    ///
    /// Monitors partial recognition results and returns immediately
    /// when any of the specified wake words is detected.
    ///
    /// **Performance:**
    /// - Typical response time: 0.5-1.5 seconds
    /// - Maximum timeout: configurable (default 3 seconds)
    ///
    /// **How it works:**
    /// - Monitors partial speech recognition results in real-time
    /// - Returns as soon as wake word appears in transcription
    /// - Cancels recognition immediately after detection
    ///
    /// - Parameters:
    ///   - wakeWords: Array of wake words to detect (case-insensitive matching)
    ///   - timeout: Maximum wait time in seconds (default: 3.0)
    /// - Returns: The detected wake word from the provided array
    /// - Throws: VoiceControlError if no wake word detected within timeout
    func recognizeWakeWord(
        wakeWords: [String],
        timeout: TimeInterval
    ) async throws -> String

    /// Force stop all ongoing speech recognition
    ///
    /// Immediately cancels any active recognition tasks and stops audio engine.
    /// Use this when user cancels voice control flow (e.g., looks away from button).
    func forceStop()
}
