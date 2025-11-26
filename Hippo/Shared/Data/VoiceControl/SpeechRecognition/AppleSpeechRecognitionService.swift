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
/// **Thread safety:**
/// This class is `@MainActor` isolated because Speech framework APIs
/// require main thread access.
@MainActor
public final class AppleSpeechRecognitionService: SpeechRecognitionService {

    // MARK: - Constants

    private enum Constants {
        static let audioBufferSize: AVAudioFrameCount = 1024
        static let recognitionTimeoutNanoseconds: UInt64 = 2_000_000_000  // 2 seconds
        static let wakeWordTimeoutNanoseconds: UInt64 = 3_000_000_000    // 3 seconds
        static let errorRetryDelayNanoseconds: UInt64 = 500_000_000      // 0.5 seconds
    }

    // MARK: - Properties

    private let speechRecognizer: SFSpeechRecognizer
    private let audioEngine = AVAudioEngine()

    /// Current active recognition task
    private var currentRecognitionTask: SFSpeechRecognitionTask?

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
        try await requestPermissions()
        return try await performRecognition()
    }

    /// Partial results 기반 빠른 wake word 감지 (0.5-1.5초, on-device)
    public func recognizeWakeWord(
        wakeWords: [String],
        timeout: TimeInterval
    ) async throws -> String {
        try await requestPermissions()
        try configureAudioSession()

        let recognitionRequest = createRecognitionRequest(forWakeWord: true)
        setupAudioTap(for: recognitionRequest)

        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
            print("🎤 [Wake Word] Audio engine started")
        } else {
            print("🎤 [Wake Word] Audio engine already running")
        }

        return try await detectWakeWordWithPartialResults(
            request: recognitionRequest,
            wakeWords: wakeWords,
            timeout: timeout
        )
    }

    /// Force stop all ongoing speech recognition
    public func forceStop() {
        print("🛑 [STT] Force stopping all recognition")

        // Cancel active recognition task
        currentRecognitionTask?.cancel()
        currentRecognitionTask = nil

        // Stop audio engine
        if audioEngine.isRunning {
            cleanup()
            audioEngine.stop()
            print("🛑 [STT] Audio engine stopped")
        }

        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🛑 [STT] Audio session deactivated")
        } catch {
            print("⚠️ [STT] Failed to deactivate audio session: \(error)")
        }
    }
}

// MARK: - Permission Handling

extension AppleSpeechRecognitionService {

    /// Speech + Microphone 권한 요청
    public func requestPermissions() async throws {
        let authStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard authStatus == .authorized else {
            throw VoiceControlError.permissionDenied
        }

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

    /// 단일 발화 음성 인식 (7초 타임아웃, cloud 허용)
    func performRecognition() async throws -> String {
        try configureAudioSession()
        let recognitionRequest = createRecognitionRequest(forWakeWord: false)
        setupAudioTap(for: recognitionRequest)

        if !audioEngine.isRunning {
            audioEngine.prepare()
            try audioEngine.start()
            print("🎤 [STT] Audio engine started")
        } else {
            print("🎤 [STT] Audio engine already running, reusing")
        }

        return try await recognizeWithTimeout(request: recognitionRequest)
    }

    /// Recognition request 생성 (wake word: on-device, command: cloud)
    func createRecognitionRequest(forWakeWord: Bool) -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = forWakeWord
        return request
    }

    /// Audio tap 설정 (기존 tap 제거 후 재설치)
    func setupAudioTap(for request: SFSpeechAudioBufferRecognitionRequest) {
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)

        inputNode.installTap(
            onBus: 0,
            bufferSize: Constants.audioBufferSize,
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

    func recognizeWithTimeout(
        request: SFSpeechAudioBufferRecognitionRequest
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let state = RecognitionState()

            let task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
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

            // Store task for potential force cancellation
            self.currentRecognitionTask = task

            setupTimeoutHandler(
                state: state,
                continuation: continuation
            )
        }
    }

    private func handleRecognitionError(
        _ error: Error,
        state: RecognitionState,
        continuation: CheckedContinuation<String, Error>
    ) {
        print("🎤 [STT Error] \(error.localizedDescription)")

        guard !state.hasResumed else { return }
        state.hasResumed = true
        currentRecognitionTask = nil
        cleanup()

        if let partial = state.lastPartialResult, !partial.isEmpty {
            print("🎤 [STT] Returning partial result on error: \"\(partial)\"")
            continuation.resume(returning: partial)
        } else {
            continuation.resume(
                throwing: VoiceControlError.speechRecognitionFailed(
                    reason: error.localizedDescription
                )
            )
        }
    }

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
            currentRecognitionTask = nil
            cleanup()
            continuation.resume(returning: transcription)
        } else {
            print("🎤 [STT Partial] \(transcription)")
            state.lastPartialResult = transcription

            Task { @MainActor in
                self.onPartialResult?(transcription)
            }
        }
    }

    private func setupTimeoutHandler(
        state: RecognitionState,
        continuation: CheckedContinuation<String, Error>
    ) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: Constants.recognitionTimeoutNanoseconds)

            guard !state.hasResumed else { return }
            state.hasResumed = true
            self.currentRecognitionTask = nil
            self.cleanup()

            if let partial = state.lastPartialResult, !partial.isEmpty {
                print("🎤 [STT] Timeout - Returning partial result: \"\(partial)\"")
                continuation.resume(returning: partial)
            } else {
                print("🎤 [STT] Timeout - No speech detected")
                continuation.resume(
                    throwing: VoiceControlError.speechRecognitionFailed(
                        reason: "No speech detected"
                    )
                )
            }
        }
    }

    /// Audio session 설정
    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Audio tap 제거 (audio engine은 계속 실행 - wake word loop 최적화)
    func cleanup() {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
    }
}

// MARK: - Wake Word Detection (Fast Mode)

private extension AppleSpeechRecognitionService {

    /// Partial results 모니터링하여 wake word 감지 시 즉시 반환 (thread-safe)
    func detectWakeWordWithPartialResults(
        request: SFSpeechAudioBufferRecognitionRequest,
        wakeWords: [String],
        timeout: TimeInterval
    ) async throws -> String {

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            var wasCancelledByDetection = false
            var recognitionTask: SFSpeechRecognitionTask?

            let normalizedWakeWords = wakeWords.map { $0.lowercased() }

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }

                Task { @MainActor in
                    if let result = result {
                        let transcription = result.bestTranscription.formattedString
                        let normalized = transcription.lowercased()

                        if result.isFinal {
                            print("🎤 [Wake Word Final] \(transcription)")
                        } else {
                            print("🎤 [Wake Word Partial] \(transcription)")
                        }

                        // Partial results에서 wake word 감지 시 즉시 반환
                        for (index, wakeWord) in normalizedWakeWords.enumerated() {
                            if normalized.contains(wakeWord) {
                                guard !hasResumed else { return }
                                hasResumed = true
                                wasCancelledByDetection = true

                                let detectedWord = wakeWords[index]
                                print("🎯 [Wake Word] DETECTED: \"\(detectedWord)\" in \"\(transcription)\"")

                                self.currentRecognitionTask = nil
                                recognitionTask?.cancel()
                                self.cleanup()

                                continuation.resume(returning: detectedWord)
                                return
                            }
                        }
                    }

                    if let error = error {
                        // 의도된 cancellation은 무시 (wake word 감지 후 cancel)
                        if wasCancelledByDetection {
                            return
                        }

                        let nsError = error as NSError
                        if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                            return
                        }

                        guard !hasResumed else { return }
                        hasResumed = true

                        print("🎤 [Wake Word Error] \(error.localizedDescription)")
                        self.currentRecognitionTask = nil
                        self.cleanup()

                        continuation.resume(
                            throwing: VoiceControlError.speechRecognitionFailed(
                                reason: error.localizedDescription
                            )
                        )
                    }
                }
            }

            // Store task for potential force cancellation
            self.currentRecognitionTask = recognitionTask

            // Timeout 설정
            Task { @MainActor in
                let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)

                guard !hasResumed else { return }
                hasResumed = true

                print("🎤 [Wake Word] Timeout after \(timeout)s - no wake word detected")

                self.currentRecognitionTask = nil
                recognitionTask?.cancel()
                self.cleanup()

                continuation.resume(
                    throwing: VoiceControlError.speechRecognitionFailed(
                        reason: "No wake word detected within \(timeout) seconds"
                    )
                )
            }
        }
    }
}
