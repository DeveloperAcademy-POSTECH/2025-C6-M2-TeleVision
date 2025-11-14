//
//  WakeWordListener.swift
//  Hippo
//
//  Presentation helper for continuous wake word detection
//
//  Responsibilities:
//  - Continuously listen for wake words in Standby mode
//  - Notify when wake word is detected
//  - Manage listening lifecycle (start/stop)
//
//  This is a presentation-layer helper, not a domain service.
//  Wake word detection is specific to this app's UX flow.
//

import Foundation
import Dependencies

/// Wake Word Listener
///
/// A lightweight helper that continuously listens for wake words
/// (e.g., "Hippo", "히포") and notifies when detected.
///
/// **Usage:**
/// ```swift
/// let listener = WakeWordListener()
/// listener.start(wakeWords: ["hippo", "히포"]) {
///     print("Wake word detected!")
/// }
/// // Later...
/// listener.stop()
/// ```
///
/// **Design rationale:**
/// - Lives in Presentation layer (not Domain) because wake word detection
///   is specific to this app's UX, not a reusable domain concept
/// - Uses SpeechRecognitionService (Domain) for actual STT
/// - Implements the continuous listening loop and wake word matching
@MainActor
final class WakeWordListener {

    // MARK: - Dependencies

    @Dependency(\.speechRecognitionService) private var speechRecognition

    // MARK: - State

    private var listeningTask: Task<Void, Never>?

    // MARK: - Public API

    /// Start listening for wake words
    ///
    /// This method continuously listens for the specified wake words.
    /// When detected, it calls the `onDetected` callback and stops listening.
    ///
    /// - Parameters:
    ///   - wakeWords: Array of wake words to detect (case-insensitive)
    ///   - onDetected: Callback called when wake word is detected
    func start(wakeWords: [String], onDetected: @escaping () -> Void) {
        print("🎧 [WakeWordListener] Starting continuous listening for: \(wakeWords)")

        // Stop any existing listening
        stop()

        // Start continuous listening loop
        listeningTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    print("🎧 [WakeWordListener] Listening...")
                    let text = try await speechRecognition.recognizeSingleUtterance()
                    print("🎧 [WakeWordListener] Heard: \"\(text)\"")

                    // Check if wake word was detected
                    if isWakeWord(text, wakeWords: wakeWords) {
                        print("🎯 [WakeWordListener] Wake word detected!")
                        onDetected()
                        break  // Stop listening after detection
                    } else {
                        print("🎧 [WakeWordListener] Not a wake word, continuing...")
                    }

                } catch {
                    print("⚠️ [WakeWordListener] Error: \(error)")
                    // Continue listening even on error, with small delay
                    // to avoid tight loop on repeated errors
                    try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
                }
            }

            print("🎧 [WakeWordListener] Stopped listening")
        }
    }

    /// Stop listening for wake words
    ///
    /// This cancels the ongoing wake word detection task.
    func stop() {
        listeningTask?.cancel()
        listeningTask = nil
    }

    // MARK: - Private Helpers

    /// Check if text contains any of the wake words
    ///
    /// Uses case-insensitive matching.
    ///
    /// - Parameters:
    ///   - text: Text to check
    ///   - wakeWords: Array of wake words to match
    /// - Returns: True if any wake word is found
    private func isWakeWord(_ text: String, wakeWords: [String]) -> Bool {
        let normalized = text.lowercased()
        return wakeWords.contains { wakeWord in
            normalized.contains(wakeWord.lowercased())
        }
    }
}
