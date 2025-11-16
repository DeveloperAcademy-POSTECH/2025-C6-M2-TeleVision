//
//  VoiceControlDependencies.swift
//  Hippo
//
//  Dependency Injection configuration for Voice Control domain
//

import Dependencies
import Foundation

// MARK: - Voice Control Dependencies

extension DependencyValues {

    // MARK: - Domain Services

    /// Voice command parser (hybrid: rule-based + LLM fallback)
    ///
    /// Uses `FallbackVoiceCommandParser` with:
    /// - Primary: `RuleBasedCommandParser` (fast, on-device)
    /// - Secondary: `LLMCommandParser` (flexible, cloud-based)
    ///
    /// The parser automatically falls back to LLM when rule-based parsing
    /// returns `.unknown` and `isLLMEnabled` is true.
    public var voiceCommandParser: VoiceCommandParser {
        get { self[VoiceCommandParserKey.self] }
        set { self[VoiceCommandParserKey.self] = newValue }
    }

    /// Speech recognition service (STT)
    ///
    /// Uses Apple's Speech framework for on-device speech recognition.
    public var speechRecognitionService: SpeechRecognitionService {
        get { self[SpeechRecognitionServiceKey.self] }
        set { self[SpeechRecognitionServiceKey.self] = newValue }
    }
}

// MARK: - Dependency Keys

private enum VoiceCommandParserKey: DependencyKey {
    static let liveValue: VoiceCommandParser = {
        // Primary: Rule-based parser (fast, on-device)
        let primary = RuleBasedCommandParser()

        // Secondary: LLM parser (flexible, cloud-based)
        // TODO: Load API key from environment or secure storage
        let secondary = LLMCommandParser(
            apiKey: "",  // Empty for now - LLM is skeleton only
            endpoint: URL(string: "https://api.openai.com/v1/chat/completions")!,
            model: "gpt-4o-mini"
        )

        // Fallback parser: Rule → LLM
        // LLM is enabled by default, but can be toggled via configuration
        return FallbackVoiceCommandParser(
            primary: primary,
            secondary: secondary,
            isLLMEnabled: true  // TODO: Load from user settings or feature flag
        )
    }()

    static let testValue: VoiceCommandParser = {
        // For tests, use rule-based only (fast, deterministic)
        return RuleBasedCommandParser()
    }()
}

private enum SpeechRecognitionServiceKey: DependencyKey {
    @MainActor
    static let liveValue: SpeechRecognitionService = {
        // Apple Speech framework implementation (English for wake word "hippo")
        return AppleSpeechRecognitionService(locale: Locale(identifier: "en-US"))
    }()

    static let testValue: SpeechRecognitionService = {
        // Mock for testing
        return MockSpeechRecognitionService()
    }()
}

// MARK: - Mock Services (for testing)

/// Mock speech recognition service for testing
private struct MockSpeechRecognitionService: SpeechRecognitionService {
    func recognizeSingleUtterance() async throws -> String {
        // Return a fixed command for testing
        return "UI 숨겨줘"
    }
}
