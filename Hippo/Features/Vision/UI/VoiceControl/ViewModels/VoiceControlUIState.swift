//
//  VoiceControlUIState.swift
//  Hippo
//
//  UI-specific state for Voice Control
//  Wraps domain state (VoiceControlState) with UI-specific properties
//

import Foundation

/// UI state for Voice Control
///
/// This struct combines domain state with UI-specific properties:
/// - Domain state: VoiceControlState (idle, standby, listening, retry)
/// - UI properties: feedback messages, transcription, errors
///
/// The feedback message is automatically computed based on current state.
/// All UI-related logic (error messages, feedback) is encapsulated here.
public struct VoiceControlUIState: Equatable {

    // MARK: - Properties

    /// Core domain state
    public var state: VoiceControlState

    /// Current feedback message to display to user
    public var feedbackMessage: String?

    /// Last recognized transcription (for debugging/UI feedback)
    public var lastTranscription: String?

    /// Last error message (for user feedback)
    public var lastErrorMessage: String?

    // MARK: - Initialization

    public init(
        state: VoiceControlState = .idle,
        feedbackMessage: String? = nil,
        lastTranscription: String? = nil,
        lastErrorMessage: String? = nil
    ) {
        self.state = state
        self.feedbackMessage = feedbackMessage
        self.lastTranscription = lastTranscription
        self.lastErrorMessage = lastErrorMessage
    }
}

// MARK: - State Management

extension VoiceControlUIState {

    /// Update state and automatically refresh feedback message
    ///
    /// Use this method instead of directly modifying `state` to ensure
    /// feedback is always in sync.
    ///
    /// - Parameter newState: The new domain state
    mutating func setState(_ newState: VoiceControlState) {
        state = newState
        updateFeedback()
    }

    /// Set error and update error message
    ///
    /// Converts VoiceControlError to user-friendly message and stores it.
    ///
    /// - Parameter error: The error that occurred
    mutating func setError(_ error: VoiceControlError) {
        lastErrorMessage = Self.errorMessage(for: error)
    }

    /// Clear error state
    mutating func clearError() {
        lastErrorMessage = nil
    }
}

// MARK: - Feedback Management

extension VoiceControlUIState {

    /// Update feedback message based on current state
    ///
    /// Call this method after changing the state to ensure
    /// feedback message is in sync with the current state.
    mutating func updateFeedback() {
        switch state {
        case .idle:
            feedbackMessage = nil

        case .standby:
            feedbackMessage = "아이콘을 바라본 상태에서 'Hippo'라고 말하면 음성 제어가 시작됩니다."

        case .listening:
            feedbackMessage = "듣는 중… 말씀을 끝내시면 명령을 실행합니다."

        case .retry:
            feedbackMessage = lastErrorMessage ?? "명령을 이해하지 못했어요. 다시 말씀해 주세요."
        }
    }
}

// MARK: - Error Message Conversion

extension VoiceControlUIState {

    /// Convert VoiceControlError to user-friendly message
    ///
    /// All error message formatting logic is centralized here,
    /// keeping ViewModel clean and focused on state management.
    ///
    /// - Parameter error: Domain error
    /// - Returns: User-friendly error message
    static func errorMessage(for error: VoiceControlError) -> String {
        switch error {
        case .permissionDenied:
            return "마이크/음성 인식 권한이 필요합니다."

        case .speechRecognitionFailed:
            return "음성을 인식하지 못했어요. 다시 시도해 주세요."

        case .noIntent:
            return "명령을 이해하지 못했어요. 다시 말씀해 주세요."

        case .parsingFailed:
            return "명령을 해석하는 중 오류가 발생했습니다."

        case .invalidParameters:
            return "명령의 파라미터가 올바르지 않습니다."

        case .unsupportedCommand:
            return "지원하지 않는 명령입니다."

        case .noSelectedEntity:
            return "조작할 3D 모델을 먼저 선택해 주세요."
        }
    }
}

// MARK: - Retry Logic Helpers

extension VoiceControlUIState {

    /// Check if error should trigger retry flow
    ///
    /// - Parameter error: The error that occurred
    /// - Returns: True if error is retryable
    static func shouldRetry(error: VoiceControlError) -> Bool {
        switch error {
        case .permissionDenied:
            // Permission errors are not retryable
            return false

        case .noSelectedEntity:
            // No entity selected - cannot retry
            return false

        case .speechRecognitionFailed, .noIntent, .parsingFailed, .invalidParameters, .unsupportedCommand:
            // These errors can be retried
            return true
        }
    }
}
