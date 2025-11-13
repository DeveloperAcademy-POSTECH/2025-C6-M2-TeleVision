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

    // MARK: - Published State

    /// UI state (combines domain state + UI-specific properties)
    public private(set) var uiState = VoiceControlUIState()

    // MARK: - Private State

    private var retryTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(commandExecutor: VoiceCommandExecutor? = nil) {
        self.commandExecutor = commandExecutor
    }

    deinit {
        cancelRetry()
    }

    // MARK: - Public API - State Transitions

    /// Called when user starts hovering over the voice control button
    ///
    /// Transition: Idle → Standby
    public func onHoverBegan() {
        guard case .idle = uiState.state else { return }

        uiState.setState(.standby)
        uiState.clearError()
    }

    /// Called when user stops hovering over the voice control button
    ///
    /// Transition: Standby/Retry → Idle
    public func onHoverEnded() {
        switch uiState.state {
        case .standby, .retry:
            cancelRetry()
            uiState.setState(.idle)
            uiState.clearError()

        case .idle, .listening:
            break
        }
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
        uiState.setState(.listening)
        uiState.clearError()

        Task { @MainActor in
            do {
                // Step 1: Recognize speech
                let text = try await speechRecognition.recognizeSingleUtterance()

                // Step 2: Handle recognized text
                try await handleRecognitionSuccess(text: text)

            } catch let error as VoiceControlError {
                // Handle voice control specific errors
                handleRecognitionFailure(error)

            } catch {
                // Handle unexpected errors
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
        let intent = try await commandParser.parse(text: text)

        // Check if intent is unknown
        if case .unknown = intent {
            throw VoiceControlError.noIntent
        }

        // Execute command
        if let executor = commandExecutor {
            try await executor.execute(intent)
        }

        // Success: Return to idle
        uiState.setState(.idle)
        uiState.clearError()
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
        retryTask = Task { [weak self] @MainActor in
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
