//
//  FallbackVoiceCommandParser.swift
//  Hippo
//
//  Hybrid voice command parser with fallback logic
//  Primary: Rule-based (fast, on-device)
//  Secondary: LLM-based (flexible, cloud)
//

import Foundation

/// Hybrid voice command parser with primary/secondary fallback strategy
///
/// This parser implements a two-tier parsing approach:
/// 1. **Primary (Rule-based)**: Fast, on-device pattern matching
/// 2. **Secondary (LLM)**: Flexible natural language understanding (fallback)
///
/// The parser first tries the primary parser. If it returns `.unknown`,
/// and LLM is enabled, it falls back to the secondary parser.
///
/// This approach optimizes for:
/// - Speed: Most common commands are handled instantly on-device
/// - Flexibility: Ambiguous commands can be interpreted by LLM
/// - Cost: LLM is only used when necessary
/// - Offline capability: Works without network for known patterns
///
/// Usage:
/// ```swift
/// let parser = FallbackVoiceCommandParser(
///     primary: RuleBasedCommandParser(),
///     secondary: LLMCommandParser(apiKey: "sk-...", endpoint: ...),
///     isLLMEnabled: true
/// )
///
/// // "UI 숨겨줘" → Handled by rule-based (fast)
/// // "살짝 왼쪽으로 돌려줘" → Falls back to LLM (flexible)
/// let intent = try await parser.parse(text: "살짝 왼쪽으로 돌려줘")
/// ```
public struct FallbackVoiceCommandParser: VoiceCommandParser {

    // MARK: - Properties

    /// Primary parser (fast, on-device)
    private let primary: VoiceCommandParser

    /// Secondary parser (flexible, cloud-based)
    private let secondary: VoiceCommandParser

    /// Whether to use LLM fallback
    ///
    /// When `false`, the parser only uses the primary parser.
    /// When `true`, unknown commands fall back to the secondary parser.
    private let isLLMEnabled: Bool

    // MARK: - Initialization

    public init(
        primary: VoiceCommandParser,
        secondary: VoiceCommandParser,
        isLLMEnabled: Bool = true
    ) {
        self.primary = primary
        self.secondary = secondary
        self.isLLMEnabled = isLLMEnabled
    }

    // MARK: - VoiceCommandParser

    public func parse(text: String) async throws -> VoiceCommandIntent {
        // Step 1: Try primary parser (rule-based)
        let primaryIntent = try await primary.parse(text: text)

        // Step 2: If primary returned unknown AND LLM is enabled, try secondary
        if isLLMEnabled {
            switch primaryIntent {
            case .unknown(let rawText):
                // Fallback to LLM for ambiguous commands
                return try await secondary.parse(text: rawText)

            default:
                // Primary parser succeeded, return result
                return primaryIntent
            }
        }

        // LLM disabled or primary succeeded
        return primaryIntent
    }
}
