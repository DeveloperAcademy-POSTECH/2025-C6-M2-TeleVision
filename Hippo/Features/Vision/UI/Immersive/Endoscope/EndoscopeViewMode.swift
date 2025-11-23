//
//  EndoscopeViewMode.swift
//  Hippo
//
//  3-stage pipeline modes for endoscope streaming
//  Mode switching with proper resource management
//

import Foundation

/// Endoscope streaming pipeline modes
/// Progressive stages: Demo (file-based) → 1 (debug) → 2 (debug) → 3 (production)
public enum EndoscopeViewMode: String, CaseIterable, Identifiable {
    /// Stage 0: File-based Demo (showcase mode) - FIRST
    /// - Purpose: Demo 3D playback without WebRTC connection
    /// - Pipeline: File → SerialProcessor → Stereo Tagged CMSampleBuffer → VideoPlayerComponent
    /// - Usage: Showcase/Demo - Play local SBS file (endoscope-demo.mp4) in 3D
    case fileDemo = "Demo"

    /// Stage 1: Raw stream view (mono or SBS as-is)
    /// - Purpose: Verify incoming video feed before any processing
    /// - Pipeline: Decoder → Raw CVPixelBuffer → Metal → Single Plane
    /// - Usage: Debug/Development - Check if video is being received
    case rawStream = "Raw Stream"

    /// Stage 2: Split SBS view (SBS separated into left/right)
    /// - Purpose: Verify SBS splitting logic and per-eye quality
    /// - Pipeline: Decoder → SBS Split → Metal → Two Planes (L/R)
    /// - Usage: Debug/Development - Check clean aperture, crop, alignment
    case splitSBS = "Split SBS"

    /// Stage 3: Stereo 3D (final production mode)
    /// - Purpose: Final stereo viewing with depth perception
    /// - Pipeline: Decoder → ConvertingModel → Stereo Tagged CMSampleBuffer → VideoPlayerComponent
    /// - Usage: Production - Medical/Clinical use with true stereo vision
    case stereo3D = "Stereo 3D"

    public var id: String { rawValue }

    /// Whether this mode requires WebRTC connection
    var requiresWebRTC: Bool {
        switch self {
        case .rawStream, .splitSBS, .stereo3D:
            return true
        case .fileDemo:
            return false  // File-based mode doesn't need WebRTC
        }
    }

    /// Icon for UI display
    var icon: String {
        switch self {
        case .rawStream: return "video.fill"
        case .splitSBS: return "rectangle.split.2x1.fill"
        case .stereo3D: return "view.3d"
        case .fileDemo: return "play.circle.fill"
        }
    }

    /// Short description for UI
    var description: String {
        switch self {
        case .rawStream: return "원본 스트림 (디버그)"
        case .splitSBS: return "SBS 좌/우 분할 (디버그)"
        case .stereo3D: return "입체 3D (프로덕션)"
        case .fileDemo: return "3D 데모 (파일)"
        }
    }

    /// Whether this mode uses Metal rendering
    var usesMetal: Bool {
        switch self {
        case .rawStream, .splitSBS: return true
        case .stereo3D, .fileDemo: return false
        }
    }

    /// Whether this mode uses VideoPlayerComponent
    var usesVideoPlayer: Bool {
        switch self {
        case .stereo3D, .fileDemo: return true
        case .rawStream, .splitSBS: return false
        }
    }

    /// Whether this mode requires ConvertingModel (SBS → Stereo tagging)
    var requiresConvertingModel: Bool {
        switch self {
        case .stereo3D: return true  // WebRTC path needs tagging
        case .fileDemo: return false  // SerialProcessor already tagged
        case .rawStream, .splitSBS: return false
        }
    }

    /// Whether this mode requires SBS splitting
    var requiresSBSSplit: Bool {
        switch self {
        case .splitSBS, .stereo3D: return true
        case .fileDemo: return false  // SerialProcessor already split
        case .rawStream: return false
        }
    }

    // MARK: - 2-Level Mode Helpers

    /// Whether this is a WebRTC mode (not file demo)
    var isWebRTCMode: Bool {
        self != .fileDemo
    }

    /// Whether this is Demo mode
    var isDemoMode: Bool {
        self == .fileDemo
    }

    /// Get next WebRTC sub-mode (cycles within WebRTC modes only)
    /// - Returns: Next WebRTC mode in cycle: raw → split → 3D → raw
    func nextWebRTCMode() -> EndoscopeViewMode {
        switch self {
        case .rawStream: return .splitSBS
        case .splitSBS:  return .stereo3D
        case .stereo3D:  return .rawStream
        case .fileDemo:  return .rawStream  // Fallback (should not be called)
        }
    }
}

/// Pipeline configuration for each mode
struct EndoscopePipelineConfig {
    let mode: EndoscopeViewMode
    let enableMetalRenderer: Bool
    let enableVideoPlayer: Bool
    let enableConvertingModel: Bool
    let enableSBSSplit: Bool

    init(mode: EndoscopeViewMode) {
        self.mode = mode
        self.enableMetalRenderer = mode.usesMetal
        self.enableVideoPlayer = mode.usesVideoPlayer
        self.enableConvertingModel = mode.requiresConvertingModel
        self.enableSBSSplit = mode.requiresSBSSplit
    }

    /// Get pipeline stages that should be active
    var activeStages: String {
        var stages: [String] = ["Decoder"]

        if enableConvertingModel {
            stages.append("ConvertingModel")
        }
        if enableSBSSplit {
            stages.append("SBS Split")
        }
        if enableMetalRenderer {
            stages.append("Metal Renderer")
        }
        if enableVideoPlayer {
            stages.append("VideoPlayer")
        }

        return stages.joined(separator: " → ")
    }
}
