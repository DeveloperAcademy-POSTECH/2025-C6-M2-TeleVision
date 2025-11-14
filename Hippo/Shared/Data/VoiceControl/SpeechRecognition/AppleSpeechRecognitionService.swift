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

    /// Handler for partial transcription results (real-time feedback)
    public var onPartialResult: (@MainActor (String) -> Void)?

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

extension AppleSpeechRecognitionService {

    /// Request necessary permissions (Speech + Microphone)
    ///
    /// This can be called before starting voice recognition to request permissions early.
    /// It's recommended to call this when the user starts a surgery session.
    public func requestPermissions() async throws {
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

        // Create and configure recognition request
        let recognitionRequest = createRecognitionRequest()

        // Setup audio tap
        setupAudioTap(for: recognitionRequest)

        // Start audio engine (only if not already running)
        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
            print("🎤 [STT] Audio engine started")
        } else {
            print("🎤 [STT] Audio engine already running, reusing")
        }

        // Perform recognition and wait for result
        return try await recognizeWithTimeout(request: recognitionRequest)
    }

    /// Create and configure recognition request
    private func createRecognitionRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // TODO: Make this configurable (on-device vs cloud) based on environment/settings
        request.requiresOnDeviceRecognition = false  // Allow cloud for better accuracy
        return request
    }

    /// Setup audio tap to feed audio to recognition request
    private func setupAudioTap(for request: SFSpeechAudioBufferRecognitionRequest) {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Remove existing tap if any (prevents errors on retry)
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) { buffer, _ in
            request.append(buffer)
        }
    }

    /// State wrapper class for recognition state
    private final class RecognitionState {
        var hasResumed = false
        var lastPartialResult: String?
    }

    /// Perform recognition with timeout handling
    private func recognizeWithTimeout(request: SFSpeechAudioBufferRecognitionRequest) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let state = RecognitionState()

            // Start recognition task
            speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                if let error = error {
                    self.handleRecognitionError(
                        error,
                        state: state,
                        continuation: continuation
                    )
                    return
                }

                if let result = result {
                    self.handleRecognitionResult(
                        result,
                        state: state,
                        continuation: continuation
                    )
                }
            }

            // Setup timeout handler
            setupTimeoutHandler(
                state: state,
                continuation: continuation
            )
        }
    }

    /// Handle recognition error
    private func handleRecognitionError(
        _ error: Error,
        state: RecognitionState,
        continuation: CheckedContinuation<String, Error>
    ) {
        print("🎤 [STT Error] \(error.localizedDescription)")

        guard !state.hasResumed else { return }
        state.hasResumed = true
        cleanup()

        // Return partial result if available, otherwise throw error
        if let partial = state.lastPartialResult, !partial.isEmpty {
            print("🎤 [STT] Returning partial result on error: \"\(partial)\"")
            continuation.resume(returning: partial)
        } else {
            continuation.resume(throwing: VoiceControlError.speechRecognitionFailed(
                reason: error.localizedDescription
            ))
        }
    }

    /// Handle recognition result (partial or final)
    private func handleRecognitionResult(
        _ result: SFSpeechRecognitionResult,
        state: RecognitionState,
        continuation: CheckedContinuation<String, Error>
    ) {
        let transcription = result.bestTranscription.formattedString

        if result.isFinal {
            print("🎤 [STT Final] \(transcription)")

            guard !state.hasResumed else { return }
            state.hasResumed = true
            cleanup()
            continuation.resume(returning: transcription)
        } else {
            print("🎤 [STT Partial] \(transcription)")
            state.lastPartialResult = transcription

            // Call partial result handler for real-time UI updates
            Task { @MainActor in
                self.onPartialResult?(transcription)
            }
        }
    }

    /// Setup timeout handler to return partial result after 7 seconds
    private func setupTimeoutHandler(
        state: RecognitionState,
        continuation: CheckedContinuation<String, Error>
    ) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Wait 7 seconds (increased from 5 to allow full command phrases)
            try? await Task.sleep(nanoseconds: 7_000_000_000)

            guard !state.hasResumed else { return }
            state.hasResumed = true
            self.cleanup()

            // Return last partial result if available
            if let partial = state.lastPartialResult, !partial.isEmpty {
                print("🎤 [STT] Timeout - Returning partial result: \"\(partial)\"")
                continuation.resume(returning: partial)
            } else {
                print("🎤 [STT] Timeout - No speech detected")
                continuation.resume(throwing: VoiceControlError.speechRecognitionFailed(
                    reason: "No speech detected"
                ))
            }
        }
    }

    /// Configure audio session for recording
    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        // It's safe to call setActive(true) multiple times
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Cleanup audio resources
    func cleanup() {
        // Don't stop audio engine! Keep it running for continuous recognition
        // This is crucial for wake word loop - stopping/starting repeatedly causes issues

        // Remove tap safely (will be re-installed on next recognition)
        let inputNode = audioEngine.inputNode
        if inputNode.numberOfInputs > 0 {
            inputNode.removeTap(onBus: 0)
        }

        // Don't deactivate audio session here!
        // This allows continuous recognition (e.g., wake word loop)
        // Audio session will be deactivated when the app goes to background
        // or when explicitly needed
    }
}
