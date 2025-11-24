import Foundation
import Dependencies

/// Wake Word Listener
///
/// Continuously listens for wake words using fast partial-result detection.
///
/// **How it works:**
/// 1. Runs continuous loop calling `recognizeWakeWord()` API
/// 2. Each attempt waits up to 3 seconds for wake word detection
/// 3. If detected: triggers callback and stops
/// 4. If timeout: retries immediately (0.1s delay)
/// 5. If error: retries after short delay (0.1s)
///
/// **Performance:**
/// - Typical detection time: 0.5-1.5 seconds
/// - Fast retry on failure (0.1s vs previous 0.5s)
/// - Uses optimized wake word API (partial results + on-device)
///
/// **Usage:**
/// ```swift
/// wakeWordListener.start(wakeWords: ["hippo"]) {
///     print("Wake word detected!")
/// }
/// ```
@MainActor
final class WakeWordListener {

    // MARK: - Constants

    private enum Constants {
        /// Retry delay after error (optimized: reduced from 0.5s to 0.1s)
        static let errorRetryDelay: UInt64 = 100_000_000          // 0.1 seconds

        /// Wake word detection timeout (fast mode)
        static let wakeWordTimeout: TimeInterval = 3.0            // 3 seconds
    }

    // MARK: - Dependencies

    @Dependency(\.speechRecognitionService) private var speechRecognition

    // MARK: - State

    private var listeningTask: Task<Void, Never>?

    // MARK: - Public Methods

    /// Start listening for wake words
    ///
    /// Runs in a continuous loop until wake word is detected or stopped.
    /// Uses fast partial-result detection for optimal performance.
    ///
    /// **Behavior:**
    /// - Automatically stops any existing listening before starting
    /// - Runs in continuous loop until wake word detected or `stop()` called
    /// - On success: calls `onDetected` callback and stops
    /// - On error: retries after 0.1s delay (fast retry for better UX)
    ///
    /// **Performance characteristics:**
    /// - Detection time: 0.5-1.5 seconds per attempt
    /// - Retry delay: 0.1 seconds (reduced from 0.5s)
    /// - Timeout per attempt: 3 seconds
    ///
    /// - Parameters:
    ///   - wakeWords: Array of wake words to detect (case-insensitive)
    ///   - onDetected: Callback called when wake word is detected
    func start(wakeWords: [String], onDetected: @escaping () -> Void) {
        print("🎧 [WakeWordListener] Starting FAST listening for: \(wakeWords)")

        // Stop any existing listening
        stop()

        // Start continuous listening loop
        listeningTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    print("🎧 [WakeWordListener] Listening (fast mode)...")

                    // Use fast wake word detection API
                    // This returns immediately when wake word is detected in partial results
                    let detectedWord = try await speechRecognition.recognizeWakeWord(
                        wakeWords: wakeWords,
                        timeout: Constants.wakeWordTimeout
                    )

                    print("🎯 [WakeWordListener] Wake word detected: \"\(detectedWord)\"")

                    // Trigger callback and stop listening
                    onDetected()
                    break

                } catch {
                    print("⚠️ [WakeWordListener] Error: \(error)")
                    // Short retry delay for better UX (reduced from 0.5s to 0.1s)
                    try? await Task.sleep(nanoseconds: Constants.errorRetryDelay)
                }
            }

            print("🎧 [WakeWordListener] Stopped listening")
        }
    }

    /// Stop listening for wake words
    ///
    /// Cancels the continuous listening loop.
    /// Safe to call multiple times.
    func stop() {
        listeningTask?.cancel()
        listeningTask = nil
    }
}
