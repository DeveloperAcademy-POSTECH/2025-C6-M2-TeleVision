//
//  VideoError.swift
//  Hippo
//
//  Common error types for video pipeline
//

import Foundation

/// Video processing errors
public enum VideoError: LocalizedError {
    // Capture errors
    case noCameraAvailable(source: CaptureSource)
    case cameraPermissionDenied
    case captureConfigurationFailed(reason: String)
    case captureStartFailed(reason: String)

    // Frame sync errors
    case frameSyncTimeout
    case frameSyncMismatch(leftPTS: Double, rightPTS: Double, deltaMs: Double)

    // Composition errors
    case compositionFailed(reason: String)
    case invalidPixelBufferFormat(expected: String, actual: String)
    case pixelBufferAllocationFailed(width: Int, height: Int)

    // Transport errors
    case transportNotStarted
    case signalingConnectionFailed(reason: String)
    case peerConnectionFailed(reason: String)
    case iceConnectionFailed

    // Configuration errors
    case invalidConfiguration(reason: String)

    public var errorDescription: String? {
        switch self {
        case .noCameraAvailable(let source):
            return "No camera available for \(source.rawValue) source"
        case .cameraPermissionDenied:
            return "Camera permission denied. Please grant access in System Preferences."
        case .captureConfigurationFailed(let reason):
            return "Capture configuration failed: \(reason)"
        case .captureStartFailed(let reason):
            return "Failed to start capture: \(reason)"

        case .frameSyncTimeout:
            return "Frame synchronization timeout"
        case .frameSyncMismatch(let leftPTS, let rightPTS, let deltaMs):
            return "Frame sync mismatch: L=\(leftPTS)s, R=\(rightPTS)s, delta=\(deltaMs)ms"

        case .compositionFailed(let reason):
            return "Frame composition failed: \(reason)"
        case .invalidPixelBufferFormat(let expected, let actual):
            return "Invalid pixel buffer format: expected \(expected), got \(actual)"
        case .pixelBufferAllocationFailed(let width, let height):
            return "Failed to allocate pixel buffer (\(width)×\(height))"

        case .transportNotStarted:
            return "Transport not started"
        case .signalingConnectionFailed(let reason):
            return "Signaling connection failed: \(reason)"
        case .peerConnectionFailed(let reason):
            return "Peer connection failed: \(reason)"
        case .iceConnectionFailed:
            return "ICE connection failed"

        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        }
    }
}
