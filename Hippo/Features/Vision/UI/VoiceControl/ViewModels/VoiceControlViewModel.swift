//
//  VoiceControlViewModel.swift
//  Hippo
//
//  Voice Control Presentation Layer
//
//  State Machine:
//  - Idle → Standby (hover begin)
//  - Standby → Listening (wake word "Hippo" detected)
//  - Listening → Idle (success) or Retry (failure)
//  - Retry → Listening (auto-retry) or Idle (timeout/give up)
//
//  Dependencies: Domain UseCases only (no Data/Infrastructure layer imports)
//

import Foundation
import Dependencies
import Observation

/// Voice Control ViewModel
///
/// Manages the voice control state machine and coordinates between:
/// - Speech recognition (STT)
/// - Command parsing (Rule-based + LLM)
/// - Command execution (UI/3D manipulation)
///
/// This ViewModel is reusable across different UI contexts:
/// - Immersive Vision UI
/// - Window-based UI
/// - Any other UI that needs hands-free voice control
///
/// **Responsibilities:**
/// - State orchestration (state machine transitions)
/// - Coordinating domain services (STT, Parser, Executor)
/// - Managing retry logic and timeouts
///
/// **Non-responsibilities (delegated to VoiceControlUIState):**
/// - UI message formatting
/// - Error message conversion
/// - Feedback message generation
@MainActor
@Observable
public final class VoiceControlViewModel {

    // MARK: - Dependencies

    @ObservationIgnored @Dependency(\.speechRecognitionService) private var speechRecognition
    @ObservationIgnored @Dependency(\.voiceCommandParser) private var commandParser
    @ObservationIgnored private var commandExecutor: VoiceCommandExecutor?

    // MARK: - Helpers

    private let wakeWordListener = WakeWordListener()

    // MARK: - Published State

    /// UI state (combines domain state + UI-specific properties)
    public private(set) var uiState = VoiceControlUIState()

    // MARK: - Private State

    private var retryTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(commandExecutor: VoiceCommandExecutor? = nil) {
        self.commandExecutor = commandExecutor

        // Setup partial result handler for real-time STT feedback
        setupPartialResultHandler()
    }

    /// Setup handler for partial STT results
    private func setupPartialResultHandler() {
        if let service = speechRecognition as? AppleSpeechRecognitionService {
            service.onPartialResult = { [weak self] partialText in
                guard let self else { return }
                Task { @MainActor in
                    self.uiState.partialTranscription = partialText
                }
            }
        }
    }


    // MARK: - Public API - State Transitions

    /// Called when user starts hovering over the voice control button
    ///
    /// Transition: Idle → Standby
    public func onHoverBegan() {
        guard case .idle = uiState.state else { return }

        print("👁️ [VoiceControl] Hover began → Standby")

        // Clear any leftover text from previous sessions
        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil

        uiState.setState(.standby)
        uiState.clearError()

        // Start continuous wake word listening
        // Using English STT, so only English wake word
        wakeWordListener.start(wakeWords: ["hippo"]) { [weak self] in
            self?.onWakeWordDetected()
        }
    }

    /// Called when user stops hovering over the voice control button
    ///
    /// Transition: Standby/Retry → Idle
    public func onHoverEnded() {
        switch uiState.state {
        case .standby, .retry:
            print("👁️ [VoiceControl] Hover ended → Idle")
            cancelRetry()
            wakeWordListener.stop()
            clearUIState()
            uiState.setState(.idle)

        case .idle, .listening:
            break
        }
    }

    /// Clear all UI state (transcriptions, errors, etc.)
    private func clearUIState() {
        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil
        uiState.clearError()
        uiState.isProcessing = false
        uiState.feedbackType = .info
    }

    /// Called when wake word "Hippo" is detected
    ///
    /// Transition: Standby → Listening
    ///
    /// This starts the full voice command pipeline:
    /// 1. Recognize single utterance (STT)
    /// 2. Parse command (Rule-based → LLM fallback)
    /// 3. Execute command (UI/3D manipulation)
    public func onWakeWordDetected() {
        guard case .standby = uiState.state else { return }
        print("🎯 [VoiceControl] Wake word detected → Starting listening flow")

        // Stop wake word listening before starting command listening
        wakeWordListener.stop()

        // Clear any previous transcriptions (new voice session starting)
        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil

        // Show wake word detected feedback
        print("🎯 [VoiceControl] Showing wake word detected feedback")
        uiState.setState(.listening)
        uiState.feedbackMessage = "Hippo 인식됨!"
        uiState.feedbackType = .success
        uiState.clearError()

        // Add small delay to clear audio buffer and show feedback
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)  // 0.8 seconds
            print("🎯 [VoiceControl] Audio buffer cleared, starting command listening")
            self.startListeningFlow()
        }
    }

    /// For testing: Start listening directly without wake word
    ///
    /// This bypasses the wake word detection and starts listening immediately.
    /// Useful for testing voice commands without saying "Hippo" first.
    public func startListeningDirectly() {
        print("🔘 [VoiceControl] Direct listening requested")

        // Cancel any ongoing tasks
        wakeWordListener.stop()
        cancelRetry()

        // Start listening flow directly
        startListeningFlow()
    }

    /// Process potential wake word input (simple text matching)
    ///
    /// Call this method when in Standby state to check if the text
    /// contains the wake word "Hippo" or "히포".
    ///
    /// - Parameter text: Text to check for wake word
    public func onWakeWordInput(_ text: String) {
        guard case .standby = uiState.state else { return }

        if isWakeWord(text) {
            onWakeWordDetected()
        }
    }

    // MARK: - Private - Wake Word Detection

    /// Check if text contains wake word
    ///
    /// Currently uses simple keyword matching.
    /// Future: Can be replaced with dedicated wake word STT flow.
    ///
    /// - Parameter text: Text to check
    /// - Returns: True if wake word is detected
    private func isWakeWord(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("hippo") || normalized.contains("히포")
    }

    // MARK: - Private - Voice Command Pipeline

    /// Start the voice command listening flow
    ///
    /// Pipeline:
    /// 1. State: Listening
    /// 2. STT: Recognize single utterance
    /// 3. Parse: Text → VoiceCommandIntent
    /// 4. Execute: Intent → Action
    /// 5. State: Idle (success) or Retry (failure)
    private func startListeningFlow() {
        print("🎧 [VoiceControl] Starting listening flow")
        uiState.setState(.listening)
        uiState.clearError()
        uiState.partialTranscription = nil  // Clear previous partial results

        Task { @MainActor in
            do {
                // Step 1: Recognize speech
                print("🎧 [VoiceControl] Step 1: Starting STT...")
                uiState.isProcessing = true
                uiState.feedbackMessage = "음성 인식 중..."
                uiState.feedbackType = .info
                let text = try await speechRecognition.recognizeSingleUtterance()
                print("🎧 [VoiceControl] STT completed: \"\(text)\"")

                // Step 2: Handle recognized text
                try await handleRecognitionSuccess(text: text)

            } catch let error as VoiceControlError {
                // Handle voice control specific errors
                print("❌ [VoiceControl] Error: \(error)")
                uiState.isProcessing = false
                handleRecognitionFailure(error)

            } catch {
                // Handle unexpected errors
                print("❌ [VoiceControl] Unexpected error: \(error)")
                uiState.isProcessing = false
                handleRecognitionFailure(.speechRecognitionFailed(reason: error.localizedDescription))
            }
        }
    }

    /// Handle successful speech recognition
    ///
    /// - Parameter text: Recognized text from STT
    private func handleRecognitionSuccess(text: String) async throws {
        // TODO: Consider duplicate detection for better UX
        // if uiState.lastTranscription == text { return }
        // This prevents re-processing the same command if STT returns duplicates

        uiState.lastTranscription = text

        // Parse command
        print("🎧 [VoiceControl] Step 2: Parsing command...")
        uiState.isProcessing = true
        uiState.feedbackMessage = "명령 분석 중..."
        uiState.feedbackType = .info
        let intent = try await commandParser.parse(text: text)
        print("🎧 [VoiceControl] Parsed intent: \(intent)")
        uiState.lastParsedIntent = "\(intent)"

        // Check if intent is unknown
        if case .unknown = intent {
            print("❌ [VoiceControl] Unknown intent")
            uiState.isProcessing = false
            throw VoiceControlError.noIntent
        }

        // Execute command
        print("🎧 [VoiceControl] Step 3: Executing command...")
        uiState.isProcessing = true
        if let executor = commandExecutor {
            try await executor.execute(intent)
            print("✅ [VoiceControl] Command executed successfully")
        } else {
            print("⚠️ [VoiceControl] No executor available")
        }

        // Show success message
        uiState.isProcessing = false
        uiState.feedbackMessage = commandDescription(for: intent)
        uiState.feedbackType = .success

        // Clear transcription texts immediately after showing success message
        // This prevents old text from appearing if user reactivates during the 1.5s wait
        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil

        // Show success message briefly
        try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 seconds

        // Success: Return to idle
        print("✅ [VoiceControl] Flow completed → Idle")
        clearUIState()
        uiState.setState(.idle)
    }

    /// Get user-friendly description for command
    private func commandDescription(for intent: VoiceCommandIntent) -> String {
        switch intent {
        case .closeMenu:
            return "메뉴가 닫힙니다"
        case .openMenu:
            return "메뉴가 열립니다"
        case .closeVideo:
            return "영상이 닫힙니다"
        case .showVideo:
            return "영상이 표시됩니다"
        case .rotateEntity(let direction, let angle):
            let dir = direction == .left ? "왼쪽" : direction == .right ? "오른쪽" : direction == .up ? "위" : "아래"
            return "\(dir)으로 \(Int(angle))도 회전합니다"
        case .unknown:
            return "알 수 없는 명령"
        }
    }

    /// Handle recognition or execution failure
    ///
    /// Decides whether to retry or give up based on error type.
    ///
    /// - Parameter error: The error that occurred
    private func handleRecognitionFailure(_ error: VoiceControlError) {
        // Set error (UIState handles message conversion)
        uiState.setError(error)

        // Decide whether to retry (UIState handles retry logic)
        if VoiceControlUIState.shouldRetry(error: error) {
            startRetryFlow()
        } else {
            // Non-retryable error: Return to idle
            uiState.setState(.idle)
        }
    }

    /// Start retry flow with automatic timeout
    ///
    /// Shows error message for 1 second, then automatically retries
    /// within 3 seconds deadline.
    private func startRetryFlow() {
        let deadline = Date().addingTimeInterval(3.0)
        uiState.setState(.retry(attempt: 1, deadline: deadline))

        // Cancel any existing retry task
        cancelRetry()

        // Schedule auto-retry
        retryTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Show error message for 1 second
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Early return if state changed
            guard case .retry = self.uiState.state else { return }

            // Early return if deadline passed
            guard Date() < deadline else {
                self.uiState.setState(.idle)
                return
            }

            // Retry
            self.startListeningFlow()
        }
    }

    /// Cancel ongoing retry task
    private func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
    }
}
