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
    /// Stage 0-A: 2D File Demo (default showcase mode)
    /// - Purpose: Simple 2D video playback without any processing
    /// - Pipeline: File → AVPlayer → VideoMaterial → Plane Entity
    /// - Usage: Default demo - Play local 2D file (demo-2d.mp4) as flat screen
    case fileDemo2D = "2D Demo"

    /// Stage 0-C: Image Demo (static image display)
    /// - Purpose: Display static image from asset catalog
    /// - Pipeline: Image → TextureResource → UnlitMaterial → Plane Entity
    /// - Usage: Demo - Display demo-image from VisionAssets
    case fileImage = "Image Demo"

    /// Stage 0-B: 3D File-based Demo (showcase mode)
    /// - Purpose: Demo 3D playback without WebRTC connection
    /// - Pipeline: File → SerialProcessor → Stereo Tagged CMSampleBuffer → VideoPlayerComponent
    /// - Usage: Showcase/Demo - Play local SBS file (endoscope-demo.mp4) in 3D
    case fileDemo = "3D Demo"

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
        case .fileDemo, .fileDemo2D, .fileImage:
            return false  // File-based modes don't need WebRTC
        }
    }

    /// Icon for UI display
    var icon: String {
        switch self {
        case .rawStream: return "video.fill"
        case .splitSBS: return "rectangle.split.2x1.fill"
        case .stereo3D: return "view.3d"
        case .fileDemo: return "cube.fill"
        case .fileDemo2D: return "play.rectangle.fill"
        case .fileImage: return "photo.fill"
        }
    }

    /// Short description for UI
    var description: String {
        switch self {
        case .rawStream: return "원본 스트림 (디버그)"
        case .splitSBS: return "SBS 좌/우 분할 (디버그)"
        case .stereo3D: return "입체 3D (프로덕션)"
        case .fileDemo: return "3D 데모 (파일)"
        case .fileDemo2D: return "2D 데모 (파일)"
        case .fileImage: return "이미지 데모"
        }
    }

    /// Whether this mode uses Metal rendering
    var usesMetal: Bool {
        switch self {
        case .rawStream, .splitSBS: return true
        case .stereo3D, .fileDemo, .fileDemo2D, .fileImage: return false
        }
    }

    /// Whether this mode uses VideoPlayerComponent
    var usesVideoPlayer: Bool {
        switch self {
        case .stereo3D, .fileDemo: return true
        case .rawStream, .splitSBS, .fileDemo2D, .fileImage: return false  // fileDemo2D uses VideoMaterial, fileImage uses TextureResource
        }
    }

    /// Whether this mode requires ConvertingModel (SBS → Stereo tagging)
    var requiresConvertingModel: Bool {
        switch self {
        case .stereo3D: return true  // WebRTC path needs tagging
        case .fileDemo: return false  // SerialProcessor already tagged
        case .rawStream, .splitSBS, .fileDemo2D, .fileImage: return false
        }
    }

    /// Whether this mode requires SBS splitting
    var requiresSBSSplit: Bool {
        switch self {
        case .splitSBS, .stereo3D: return true
        case .fileDemo: return false  // SerialProcessor already split
        case .rawStream, .fileDemo2D, .fileImage: return false  // fileDemo2D is mono, fileImage is static image
        }
    }

    // MARK: - 2-Level Mode Helpers

    /// Whether this is a WebRTC mode (not file demo)
    var isWebRTCMode: Bool {
        switch self {
        case .rawStream, .splitSBS, .stereo3D: return true
        case .fileDemo, .fileDemo2D, .fileImage: return false
        }
    }

    /// Whether this is Demo mode (file-based)
    var isDemoMode: Bool {
        switch self {
        case .fileDemo, .fileDemo2D, .fileImage: return true
        case .rawStream, .splitSBS, .stereo3D: return false
        }
    }

    /// Whether this is 2D Demo mode
    var is2DDemo: Bool {
        self == .fileDemo2D
    }

    /// Whether this is 3D Demo mode
    var is3DDemo: Bool {
        self == .fileDemo
    }

    /// Whether this is Image Demo mode
    var isImageDemo: Bool {
        self == .fileImage
    }

    /// Get next WebRTC sub-mode (cycles within WebRTC modes only)
    /// - Returns: Next WebRTC mode in cycle: raw → split → 3D → raw
    func nextWebRTCMode() -> EndoscopeViewMode {
        switch self {
        case .rawStream: return .splitSBS
        case .splitSBS:  return .stereo3D
        case .stereo3D:  return .rawStream
        case .fileDemo, .fileDemo2D, .fileImage:  return .rawStream  // Fallback (should not be called)
        }
    }
}

// MARK: - Render Configuration

/// Video layout type for rendering
public enum VideoLayout {
    /// 2D plane - same texture for both eyes
    case monoPlane
    /// File-based SBS → split to left/right stereo
    case stereoFromSBS
    /// WebRTC stereo stream (already split)
    case stereoStream
}

/// Video source type
public enum VideoSource {
    /// Local file playback
    case file(url: URL)
    /// WebRTC stream
    case webrtc
    /// Static image from asset catalog
    case image(name: String)
}

/// Render configuration for each mode
public struct EndoscopeRenderConfig {
    public let layout: VideoLayout
    public let source: VideoSource
}

extension EndoscopeViewMode {
    /// Get render configuration for this mode
    var renderConfig: EndoscopeRenderConfig {
        switch self {
        case .fileDemo2D:
            return EndoscopeRenderConfig(
                layout: .monoPlane,
                source: .file(url: Bundle.main.url(forResource: "demo-2d", withExtension: "mp4")!)
            )

        case .fileDemo:
            return EndoscopeRenderConfig(
                layout: .stereoFromSBS,
                source: .file(url: Bundle.main.url(forResource: "endoscope-demo", withExtension: "mp4")!)
            )

        case .rawStream:
            return EndoscopeRenderConfig(
                layout: .monoPlane,
                source: .webrtc
            )

        case .splitSBS:
            return EndoscopeRenderConfig(
                layout: .monoPlane,
                source: .webrtc
            )

        case .stereo3D:
            return EndoscopeRenderConfig(
                layout: .stereoStream,
                source: .webrtc
            )

        case .fileImage:
            return EndoscopeRenderConfig(
                layout: .monoPlane,
                source: .image(name: "demo-image")
            )
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
