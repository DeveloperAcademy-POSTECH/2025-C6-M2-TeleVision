import Foundation
import Dependencies

@MainActor
final class WakeWordListener {

    // MARK: - Constants

    private enum Constants {
        static let errorRetryDelay: UInt64 = 500_000_000  // 0.5 seconds
    }

    // MARK: - Dependencies

    @Dependency(\.speechRecognitionService) private var speechRecognition

    // MARK: - State

    private var listeningTask: Task<Void, Never>?

    // MARK: - Public Methods

    /// Start listening for wake words
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
                    try? await Task.sleep(nanoseconds: Constants.errorRetryDelay)
                }
            }

            print("🎧 [WakeWordListener] Stopped listening")
        }
    }

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
