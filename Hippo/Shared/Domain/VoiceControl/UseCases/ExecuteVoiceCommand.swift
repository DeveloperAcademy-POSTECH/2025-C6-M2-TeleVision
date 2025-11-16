//
//  ExecuteVoiceCommand.swift
//  Hippo
//

import Foundation

/// Use case for executing a voice command intent
public struct ExecuteVoiceCommand: Sendable {
    public struct Input: Sendable {
        public let intent: VoiceCommandIntent

        public init(intent: VoiceCommandIntent) {
            self.intent = intent
        }
    }

    private let executor: VoiceCommandExecutor

    public init(executor: VoiceCommandExecutor) {
        self.executor = executor
    }

    /// Execute the voice command intent
    ///
    /// - Parameter input: Input containing the intent to execute
    /// - Throws: VoiceControlError if execution fails
    public func run(_ input: Input) async throws {
        try await executor.execute(input.intent)
    }
}
