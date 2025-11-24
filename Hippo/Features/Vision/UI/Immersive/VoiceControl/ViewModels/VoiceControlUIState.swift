import Foundation

// MARK: - UI State Enums

public enum VoiceFeedbackColor: Equatable {
    case success
    case error
    case info
}

public enum VoiceStatusMessageKey: Equatable {
    case none
    case standbyGuide
    case listening
    case processing
    case retry(errorMessage: String?)
}

// MARK: - UI State

public struct VoiceControlUIState: Equatable {

    // MARK: - Properties - State

    /// Core domain state
    public var state: VoiceControlState

    /// Type of current feedback message (for styling)
    public var feedbackType: FeedbackType = .info

    // MARK: - Properties - Messages

    /// Current feedback message to display to user
    public var feedbackMessage: String?

    /// Last error message (for user feedback)
    public var lastErrorMessage: String?

    // MARK: - Properties - Transcriptions

    /// Real-time partial transcription (shown while listening)
    public var partialTranscription: String?

    /// Last recognized transcription (for debugging/UI feedback)
    public var lastTranscription: String?

    /// Last parsed intent (for debugging/UI feedback)
    public var lastParsedIntent: String?

    // MARK: - Properties - Processing

    /// Whether currently processing (recognition or parsing)
    public var isProcessing: Bool = false

    // MARK: - Initialization

    public init(
        state: VoiceControlState = .idle,
        feedbackMessage: String? = nil,
        partialTranscription: String? = nil,
        lastTranscription: String? = nil,
        lastParsedIntent: String? = nil,
        lastErrorMessage: String? = nil,
        isProcessing: Bool = false,
        feedbackType: FeedbackType = .info
    ) {
        self.state = state
        self.feedbackMessage = feedbackMessage
        self.partialTranscription = partialTranscription
        self.lastTranscription = lastTranscription
        self.lastParsedIntent = lastParsedIntent
        self.lastErrorMessage = lastErrorMessage
        self.isProcessing = isProcessing
        self.feedbackType = feedbackType
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
            feedbackMessage = "'Hippo'라고 말하세요"

        case .listening:
            feedbackMessage = "명령을 말씀해주세요"

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

// MARK: - UI Helpers (Pure Swift)

extension VoiceControlUIState {

    /// Status message key (View resolves to actual text)
    public var statusMessageKey: VoiceStatusMessageKey {
        switch state {
        case .idle:
            return .none
        case .standby:
            return .standbyGuide
        case .listening:
            if isProcessing {
                return .processing
            } else if feedbackType == .success {
                return .none
            } else {
                return .listening
            }
        case .retry:
            return .retry(errorMessage: lastErrorMessage)
        }
    }

    /// Whether to show feedback message
    public var shouldShowFeedback: Bool {
        state == .listening && !isProcessing
    }

    /// Feedback color key (View maps to SwiftUI Color)
    public var feedbackColorKey: VoiceFeedbackColor {
        switch feedbackType {
        case .success: return .success
        case .error: return .error
        case .info: return .info
        }
    }

    /// Status color key (View maps to SwiftUI Color)
    public var statusColorKey: VoiceFeedbackColor {
        switch state {
        case .idle, .standby: return .info
        case .listening: return .success
        case .retry: return .error
        }
    }
}
