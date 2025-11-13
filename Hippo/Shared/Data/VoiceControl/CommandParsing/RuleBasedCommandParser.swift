//
//  RuleBasedCommandParser.swift
//  Hippo
//
//  Rule-based voice command parser (v1)
//  Fast, on-device parsing using pattern matching
//

import Foundation

/// Rule-based implementation of VoiceCommandParser
///
/// This parser uses keyword matching and regex patterns to parse commands.
/// It's fast, works offline, and doesn't require external API calls.
///
/// Supported patterns:
/// - "UI 숨겨줘", "UI 닫아줘" → hideUI
/// - "UI 보여줘", "UI 표시해줘" → showUI
/// - "패널 닫아줘", "창 닫아줘" → closePanel
/// - "영상만 크게", "영상만 보여줘" → showVideoOnly
/// - "왼쪽으로 30도 회전" → rotateEntity(left, 30)
/// - "오른쪽으로 10도 돌려줘" → rotateEntity(right, 10)
public struct RuleBasedCommandParser: VoiceCommandParser {

    public init() {}

    public func parse(text: String) async throws -> VoiceCommandIntent {
        let normalized = normalize(text)

        // 1. Hide UI patterns
        if matchesHideUI(normalized) {
            return .hideUI
        }

        // 2. Show UI patterns
        if matchesShowUI(normalized) {
            return .showUI
        }

        // 3. Close Panel patterns
        if matchesClosePanel(normalized) {
            return .closePanel
        }

        // 4. Show Video Only patterns
        if matchesShowVideoOnly(normalized) {
            return .showVideoOnly
        }

        // 5. Rotation patterns (most complex, check last)
        if let rotation = parseRotation(normalized) {
            return rotation
        }

        // No match found - return unknown
        return .unknown(rawText: text)
    }
}

// MARK: - Text Normalization

private extension RuleBasedCommandParser {

    /// Normalize text for consistent pattern matching
    ///
    /// Current normalization:
    /// - Lowercase conversion
    /// - Whitespace trimming
    /// - Multiple spaces → single space
    ///
    /// Future extensions:
    /// - Remove punctuation (.?!)
    /// - Normalize polite expressions (해주세요 → 해줘)
    /// - Remove filler words
    func normalize(_ text: String) -> String {
        return text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }
}

// MARK: - Pattern Matching Helpers

private extension RuleBasedCommandParser {

    /// Check if text matches "Hide UI" command
    func matchesHideUI(_ text: String) -> Bool {
        let patterns = [
            "ui 숨겨",
            "ui 닫아",
            "ui 가려",
            "화면 숨겨",
            "인터페이스 숨겨"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Check if text matches "Show UI" command
    func matchesShowUI(_ text: String) -> Bool {
        let patterns = [
            "ui 보여",
            "ui 표시",
            "ui 켜",
            "화면 보여",
            "인터페이스 보여"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Check if text matches "Close Panel" command
    func matchesClosePanel(_ text: String) -> Bool {
        let patterns = [
            "패널 닫아",
            "창 닫아",
            "패널 종료",
            "창 종료"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Check if text matches "Show Video Only" command
    ///
    /// More strict patterns to avoid false positives
    func matchesShowVideoOnly(_ text: String) -> Bool {
        let patterns = [
            "영상만 보여",
            "영상만 크게",
            "영상만 보이게",
            "비디오만",
            "동영상만"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Parse rotation command with direction and angle
    ///
    /// Patterns:
    /// - "왼쪽으로 30도 회전" → rotateEntity(left, 30)
    /// - "오른쪽 10도 돌려줘" → rotateEntity(right, 10)
    /// - "위로 45도" → rotateEntity(up, 45)
    func parseRotation(_ text: String) -> VoiceCommandIntent? {
        // Keywords that indicate rotation command (removed "도" to avoid false positives)
        let rotationKeywords = ["회전", "돌려", "돌아"]
        guard rotationKeywords.contains(where: { text.contains($0) }) else {
            return nil
        }

        // Extract direction
        guard let direction = extractDirection(from: text) else {
            return nil
        }

        // Extract angle (default to 15 degrees if not specified)
        let angle = extractAngle(from: text) ?? 15.0

        // Validate angle range
        guard angle > 0 && angle <= 360 else {
            return nil
        }

        return .rotateEntity(direction: direction, angle: angle)
    }

    /// Extract rotation direction from text
    func extractDirection(from text: String) -> RotationDirection? {
        if text.contains("왼쪽") || text.contains("좌") {
            return .left
        } else if text.contains("오른쪽") || text.contains("우") {
            return .right
        } else if text.contains("위") || text.contains("상") {
            return .up
        } else if text.contains("아래") || text.contains("하") {
            return .down
        }
        return nil
    }

    /// Extract angle from text using regex
    ///
    /// Examples:
    /// - "30도" → 30.0
    /// - "45도 회전" → 45.0
    /// - "10도 돌려줘" → 10.0
    func extractAngle(from text: String) -> Double? {
        // Regex pattern: capture digits before "도"
        let pattern = #"(\d+(?:\.\d+)?)\s*도"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ) else {
            return nil
        }

        // Extract the number string
        guard let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }

        let numberString = String(text[numberRange])
        return Double(numberString)
    }
}
