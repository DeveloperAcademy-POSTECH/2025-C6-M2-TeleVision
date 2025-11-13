//
//  StartVoiceListening.swift
//  Hippo
//

import Foundation

/// Use case for starting voice recognition and capturing a single utterance
public struct StartVoiceListening: Sendable {
    private let speechRecognition: SpeechRecognitionService

    public init(speechRecognition: SpeechRecognitionService) {
        self.speechRecognition = speechRecognition
    }

    /// Start listening and recognize a single utterance
    ///
    /// - Returns: Transcribed text from the utterance
    /// - Throws: VoiceControlError if speech recognition fails
    public func run() async throws -> String {
        try await speechRecognition.recognizeSingleUtterance()
    }
}
