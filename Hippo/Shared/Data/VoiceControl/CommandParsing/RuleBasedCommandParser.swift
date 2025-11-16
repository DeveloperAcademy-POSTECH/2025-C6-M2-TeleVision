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
/// - "메뉴 닫아줘", "close menu" → closeMenu
/// - "메뉴 열어줘", "open menu" → openMenu
/// - "비디오 닫아줘", "close video" → closeVideo
/// - "비디오 보여줘", "show video" → showVideo
/// - "왼쪽으로 30도 회전" → rotateEntity(left, 30)
/// - "오른쪽으로 10도 돌려줘" → rotateEntity(right, 10)
public struct RuleBasedCommandParser: VoiceCommandParser {

    public init() {}

    public func parse(text: String) async throws -> VoiceCommandIntent {
        print("🔍 [Parser] Input text: \"\(text)\"")
        let normalized = normalize(text)
        print("🔍 [Parser] Normalized: \"\(normalized)\"")

        // 1. Close Menu patterns
        if matchesCloseMenu(normalized) {
            print("✅ [Parser] Matched: closeMenu")
            return .closeMenu
        }

        // 2. Open Menu patterns
        if matchesOpenMenu(normalized) {
            print("✅ [Parser] Matched: openMenu")
            return .openMenu
        }

        // 3. Close Video patterns
        if matchesCloseVideo(normalized) {
            print("✅ [Parser] Matched: closeVideo")
            return .closeVideo
        }

        // 4. Show Video patterns
        if matchesShowVideo(normalized) {
            print("✅ [Parser] Matched: showVideo")
            return .showVideo
        }

        // 5. Rotation patterns (most complex, check last)
        if let rotation = parseRotation(normalized) {
            print("✅ [Parser] Matched: \(rotation)")
            return rotation
        }

        // No match found - return unknown
        print("❌ [Parser] No match found - returning unknown")
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

    /// Check if text matches "Close Menu" command
    func matchesCloseMenu(_ text: String) -> Bool {
        let patterns = [
            // Korean
            "메뉴 닫아",
            "메뉴 숨겨",
            "메뉴 종료",
            "메뉴 가려",
            "컨트롤 닫아",
            "설정 닫아",
            "패널 닫아",
            // English
            "close menu",
            "close the menu",
            "hide menu",
            "hide the menu",
            "menu off",
            "close control",
            "hide control"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Check if text matches "Open Menu" command
    func matchesOpenMenu(_ text: String) -> Bool {
        let patterns = [
            // Korean
            "메뉴 열어",
            "메뉴 보여",
            "메뉴 켜",
            "메뉴 표시",
            "컨트롤 열어",
            "설정 열어",
            "패널 열어",
            // English
            "open menu",
            "open the menu",
            "show menu",
            "show the menu",
            "menu on",
            "display menu",
            "open control",
            "show control"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Check if text matches "Close Video" command
    func matchesCloseVideo(_ text: String) -> Bool {
        let patterns = [
            // Korean
            "비디오 닫아",
            "영상 닫아",
            "동영상 닫아",
            "비디오 종료",
            "영상 종료",
            "내시경 닫아",
            // English
            "close video",
            "close the video",
            "hide video",
            "hide the video",
            "video off",
            "close endoscope",
            "hide endoscope"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Check if text matches "Show Video" command
    func matchesShowVideo(_ text: String) -> Bool {
        let patterns = [
            // Korean
            "비디오 보여",
            "영상 보여",
            "동영상 보여",
            "비디오 열어",
            "영상 열어",
            "내시경 보여",
            "영상만",
            "비디오만",
            // English
            "show video",
            "show the video",
            "open video",
            "open the video",
            "video on",
            "video only",
            "show endoscope",
            "open endoscope"
        ]
        return patterns.contains { text.contains($0) }
    }

    /// Parse rotation command with direction and angle
    ///
    /// Patterns:
    /// - "왼쪽으로 30도 회전" → rotateEntity(left, 30)
    /// - "오른쪽 10도 돌려줘" → rotateEntity(right, 10)
    /// - "위로 45도" → rotateEntity(up, 45)
    /// - "rotate left 30 degrees" → rotateEntity(left, 30)
    /// - "turn right 10" → rotateEntity(right, 10)
    func parseRotation(_ text: String) -> VoiceCommandIntent? {
        // Keywords that indicate rotation command
        let rotationKeywords = ["회전", "돌려", "돌아", "rotate", "turn", "spin"]
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
        // Korean
        if text.contains("왼쪽") || text.contains("좌") {
            return .left
        } else if text.contains("오른쪽") || text.contains("우") {
            return .right
        } else if text.contains("위") || text.contains("상") {
            return .up
        } else if text.contains("아래") || text.contains("하") {
            return .down
        }
        // English
        else if text.contains("left") {
            return .left
        } else if text.contains("right") {
            return .right
        } else if text.contains("up") {
            return .up
        } else if text.contains("down") {
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
