//
//  ParseVoiceCommand.swift
//  Hippo
//

import Foundation

/// Use case for parsing voice command text into intent
public struct ParseVoiceCommand: Sendable {
    public struct Input: Sendable {
        public let text: String

        public init(text: String) {
            self.text = text
        }
    }

    private let parser: VoiceCommandParser

    public init(parser: VoiceCommandParser) {
        self.parser = parser
    }

    /// Parse voice command text into a structured intent
    ///
    /// - Parameter input: Input containing recognized text from STT
    /// - Returns: Parsed voice command intent
    /// - Throws: VoiceControlError if parsing fails
    public func run(_ input: Input) async throws -> VoiceCommandIntent {
        try await parser.parse(text: input.text)
    }
}
