//
//  AppleSpeechRecognitionService.swift
//  Hippo
//
//  Apple Speech framework implementation of SpeechRecognitionService
//  Data layer only - Domain/Presentation layers must NOT import Speech
//

import Foundation
import Speech
import AVFoundation

/// Apple Speech framework implementation of SpeechRecognitionService
///
/// This service uses Apple's on-device speech recognition (Speech framework)
/// to recognize a single utterance and return the transcribed text.
///
/// **Implementation details:**
/// - Uses `SFSpeechAudioBufferRecognitionRequest` for live audio recognition
/// - Configures for Korean language (`ko-KR`)
/// - Automatically stops after detecting a complete utterance
/// - Handles microphone permissions via `AVAudioSession`
///
/// **Thread safety:**
/// This class is `@MainActor` isolated because Speech framework APIs
/// require main thread access.
@MainActor
public final class AppleSpeechRecognitionService: SpeechRecognitionService {

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization

    public init(locale: Locale = Locale(identifier: "ko-KR")) {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            fatalError("Speech recognizer not available for locale: \(locale)")
        }
        self.speechRecognizer = recognizer
    }

    // MARK: - SpeechRecognitionService

    public func recognizeSingleUtterance() async throws -> String {
        // Step 1: Request permissions
        try await requestPermissions()

        // Step 2: Start recognition and wait for result
        return try await performRecognition()
    }
}

// MARK: - Permission Handling

private extension AppleSpeechRecognitionService {

    /// Request necessary permissions (Speech + Microphone)
    func requestPermissions() async throws {
        // Request speech recognition permission
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            throw VoiceControlError.permissionDenied
        }

        // Request microphone permission
        let recordPermission = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard recordPermission else {
            throw VoiceControlError.permissionDenied
        }
    }
}

// MARK: - Recognition

private extension AppleSpeechRecognitionService {

    /// Perform speech recognition for a single utterance
    ///
    /// This method:
    /// 1. Configures audio session
    /// 2. Starts audio engine
    /// 3. Creates recognition request
    /// 4. Waits for final transcription
    /// 5. Stops audio engine
    /// 6. Returns transcribed text
    func performRecognition() async throws -> String {
        // Configure audio session
        try configureAudioSession()

        // Create recognition request
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        // TODO: Make this configurable (on-device vs cloud) based on environment/settings
        recognitionRequest.requiresOnDeviceRecognition = false  // Allow cloud for better accuracy

        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install audio tap to feed audio to recognition request
        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Perform recognition and wait for result
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }

                // Handle error
                if let error = error {
                    if !hasResumed {
                        hasResumed = true
                        self.cleanup()
                        continuation.resume(throwing: VoiceControlError.speechRecognitionFailed(
                            reason: error.localizedDescription
                        ))
                    }
                    return
                }

                // Handle result
                if let result = result {
                    // Check if this is a final result
                    if result.isFinal {
                        let transcription = result.bestTranscription.formattedString

                        if !hasResumed {
                            hasResumed = true
                            self.cleanup()
                            continuation.resume(returning: transcription)
                        }
                    }
                }
            }

            // Timeout: If no final result after 10 seconds, use timeout error
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 10_000_000_000)  // 10 seconds

                if !hasResumed {
                    hasResumed = true
                    self.cleanup()
                    continuation.resume(throwing: VoiceControlError.speechRecognitionFailed(
                        reason: "Recognition timeout"
                    ))
                }
            }
        }
    }

    /// Configure audio session for recording
    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Cleanup audio resources
    func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
