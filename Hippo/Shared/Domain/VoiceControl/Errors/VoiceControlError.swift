//
//  VoiceControlError.swift
//  Hippo
//

import Foundation

/// Voice control domain errors
public enum VoiceControlError: Error, Equatable, Sendable {
    /// Speech recognition failed (STT error)
    case speechRecognitionFailed(reason: String)

    /// Command parsing failed
    case parsingFailed(reason: String)

    /// No recognizable intent found in the command
    case noIntent

    /// Command parameters are invalid (e.g., negative angle)
    case invalidParameters(String)

    /// Command is not supported
    case unsupportedCommand(String)

    /// Permission denied (microphone access)
    case permissionDenied
}

// MARK: - LocalizedError

extension VoiceControlError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .speechRecognitionFailed(let reason):
            return "음성 인식 실패: \(reason)"
        case .parsingFailed(let reason):
            return "명령 해석 실패: \(reason)"
        case .noIntent:
            return "명령을 이해하지 못했습니다"
        case .invalidParameters(let detail):
            return "잘못된 명령 파라미터: \(detail)"
        case .unsupportedCommand(let command):
            return "지원하지 않는 명령: \(command)"
        case .permissionDenied:
            return "마이크 접근 권한이 필요합니다"
        }
    }
}
