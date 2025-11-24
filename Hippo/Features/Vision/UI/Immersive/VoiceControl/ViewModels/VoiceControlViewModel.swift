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

import Foundation
import Dependencies
import Observation

@MainActor
@Observable
public final class VoiceControlViewModel {

    // MARK: - Constants

    private enum Constants {
        /// Wake word 피드백 표시 시간 (0.1s → 0.8s로 증가하여 시각적 인지 개선)
        static let wakeWordFeedbackDelay: UInt64 = 800_000_000      // 0.8 seconds

        static let successMessageDuration: UInt64 = 1_500_000_000 // 1.5 seconds
        static let errorMessageDuration: UInt64 = 1_000_000_000   // 1 second
        static let retryDeadlineSeconds: TimeInterval = 3.0
    }

    // MARK: - Dependencies

    @ObservationIgnored
    @Dependency(\.speechRecognitionService) private var speechRecognition

    @ObservationIgnored
    @Dependency(\.voiceCommandParser) private var commandParser

    @ObservationIgnored
    private var commandExecutor: VoiceCommandExecutor?

    // MARK: - Helpers

    private let wakeWordListener = WakeWordListener()

    // MARK: - Published State

    public private(set) var uiState = VoiceControlUIState()

    // MARK: - Private State

    private var retryTask: Task<Void, Never>?
    private var listeningTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(commandExecutor: VoiceCommandExecutor? = nil) {
        self.commandExecutor = commandExecutor
        setupPartialResultHandler()
    }

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
    public func onHoverBegan() {
        guard case .idle = uiState.state else { return }

        print("👁️ [VoiceControl] Hover began → Standby")

        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil

        uiState.setState(.standby)
        uiState.clearError()

        wakeWordListener.start(wakeWords: ["hippo"]) { [weak self] in
            self?.onWakeWordDetected()
        }
    }

    /// Called when user stops hovering over the voice control button
    public func onHoverEnded() {
        switch uiState.state {
        case .standby, .retry:
            print("👁️ [VoiceControl] Hover ended → Idle")
            cancelRetry()
            wakeWordListener.stop()
            clearUIState()
            uiState.setState(.idle)

        case .listening:
            // Force stop listening when user looks away during active recognition
            print("👁️ [VoiceControl] Hover ended during listening → Force stop")
            forceStopListening()
            clearUIState()
            uiState.setState(.idle)

        case .idle:
            break
        }
    }

    private func clearUIState() {
        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil
        uiState.clearError()
        uiState.isProcessing = false
        uiState.feedbackType = .info
    }

    /// Wake word 감지 시 호출 - 0.8초 피드백 유지 후 command listening 시작
    public func onWakeWordDetected() {
        guard case .standby = uiState.state else { return }
        print("🎯 [VoiceControl] Wake word detected → Starting listening flow")

        wakeWordListener.stop()

        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil

        print("🎯 [VoiceControl] Showing wake word detected feedback")
        uiState.setState(.listening)
        uiState.feedbackMessage = "Hippo 인식됨!"
        uiState.feedbackType = .success
        uiState.clearError()

        // 0.8초 피드백 유지 후 "명령을 말씀해주세요"로 변경
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Constants.wakeWordFeedbackDelay)

            guard case .listening = self.uiState.state else {
                print("🎯 [VoiceControl] State changed during feedback delay, aborting")
                return
            }

            print("🎯 [VoiceControl] Feedback displayed (0.8s), showing command prompt")
            self.uiState.feedbackMessage = "명령을 말씀해주세요"
            self.uiState.feedbackType = .info

            self.startListeningFlow()
        }
    }

    /// For testing: Start listening directly without wake word
    public func startListeningDirectly() {
        print("🔘 [VoiceControl] Direct listening requested")

        wakeWordListener.stop()
        cancelRetry()

        startListeningFlow()
    }

    /// Process potential wake word input (simple text matching)
    public func onWakeWordInput(_ text: String) {
        guard case .standby = uiState.state else { return }

        if isWakeWord(text) {
            onWakeWordDetected()
        }
    }

    // MARK: - Private - Wake Word Detection

    private func isWakeWord(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("hippo") || normalized.contains("히포")
    }

    // MARK: - Private - Voice Command Pipeline

    private func startListeningFlow() {
        print("🎧 [VoiceControl] Starting listening flow")
        uiState.setState(.listening)
        uiState.clearError()
        uiState.partialTranscription = nil

        // Cancel any existing listening task
        listeningTask?.cancel()

        listeningTask = Task { @MainActor in
            do {
                print("🎧 [VoiceControl] Starting STT...")
                uiState.isProcessing = true
                // Keep "명령을 말씀해주세요" message instead of changing it
                let text = try await speechRecognition.recognizeSingleUtterance()
                print("🎧 [VoiceControl] STT completed: \"\(text)\"")

                try await handleRecognitionSuccess(text: text)

            } catch let error as VoiceControlError {
                print("❌ [VoiceControl] Error: \(error)")
                uiState.isProcessing = false
                handleRecognitionFailure(error)

            } catch {
                print("❌ [VoiceControl] Unexpected error: \(error)")
                uiState.isProcessing = false
                handleRecognitionFailure(
                    .speechRecognitionFailed(reason: error.localizedDescription)
                )
            }
        }
    }

    /// Force stop all ongoing listening operations
    private func forceStopListening() {
        print("🛑 [VoiceControl] Force stopping listening flow")

        // Cancel listening task
        listeningTask?.cancel()
        listeningTask = nil

        // Force stop speech recognition service
        speechRecognition.forceStop()

        // Stop wake word listener
        wakeWordListener.stop()
    }

    private func handleRecognitionSuccess(text: String) async throws {
        uiState.lastTranscription = text

        print("🎧 [VoiceControl] Parsing command...")
        uiState.isProcessing = true
        uiState.feedbackMessage = "명령 분석 중..."
        uiState.feedbackType = .info
        let intent = try await commandParser.parse(text: text)
        print("🎧 [VoiceControl] Parsed intent: \(intent)")
        uiState.lastParsedIntent = "\(intent)"

        // Handle cancel command specially - immediate stop
        if case .cancelVoiceControl = intent {
            print("🛑 [VoiceControl] Cancel command received - stopping")
            uiState.isProcessing = false
            uiState.feedbackMessage = "음성 제어를 종료합니다"
            uiState.feedbackType = .info

            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            clearUIState()
            uiState.setState(.idle)
            return
        }

        if case .unknown = intent {
            print("❌ [VoiceControl] Unknown intent")
            uiState.isProcessing = false
            throw VoiceControlError.noIntent
        }

        print("🎧 [VoiceControl] Executing command...")
        uiState.isProcessing = true
        if let executor = commandExecutor {
            try await executor.execute(intent)
            print("✅ [VoiceControl] Command executed successfully")
        } else {
            print("⚠️ [VoiceControl] No executor available")
        }

        uiState.isProcessing = false
        uiState.feedbackMessage = commandDescription(for: intent)
        uiState.feedbackType = .success

        uiState.partialTranscription = nil
        uiState.lastTranscription = nil
        uiState.lastParsedIntent = nil

        try? await Task.sleep(nanoseconds: Constants.successMessageDuration)

        print(" [VoiceControl] Flow completed → Idle")
        clearUIState()
        uiState.setState(.idle)
    }

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
            let dir: String
            switch direction {
            case .left:
                dir = "왼쪽"
            case .right:
                dir = "오른쪽"
            case .up:
                dir = "위"
            case .down:
                dir = "아래"
            }
            return "\(dir)으로 \(Int(angle))도 회전합니다"
        case .cancelVoiceControl:
            return "음성 제어를 종료합니다"
        case .unknown:
            return "알 수 없는 명령"
        }
    }

    private func handleRecognitionFailure(_ error: VoiceControlError) {
        uiState.setError(error)

        if VoiceControlUIState.shouldRetry(error: error) {
            startRetryFlow()
        } else {
            uiState.setState(.idle)
        }
    }

    private func startRetryFlow() {
        let deadline = Date().addingTimeInterval(Constants.retryDeadlineSeconds)
        uiState.setState(.retry(attempt: 1, deadline: deadline))

        cancelRetry()

        retryTask = Task { @MainActor [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: Constants.errorMessageDuration)

            guard case .retry = self.uiState.state else { return }

            guard Date() < deadline else {
                self.uiState.setState(.idle)
                return
            }

            self.startListeningFlow()
        }
    }

    private func cancelRetry() {
        retryTask?.cancel()
        retryTask = nil
    }
}
