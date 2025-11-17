//
//  EndoscopeRenderPipeline.swift
//  Hippo
//
//  3-Stage Rendering Pipeline for OR Demo
//  Stage 1: Raw SBS (VideoPlayer, safest fallback)
//  Stage 2: Left-only Mono (VideoPlayer, 2D for OR)
//  Stage 3: Stereo 3D (VideoPlayer, immersive)
//

import Foundation
import AVFoundation
import CoreVideo
import CoreMedia
import os.log
import Combine

/// Manages rendering pipeline for different view modes
/// All modes use VideoPlayer for stability
@MainActor
public final class EndoscopeRenderPipeline: ObservableObject {

    // MARK: - Published Properties

    @Published public var currentFrameSize: CGSize = .zero

    // MARK: - Callbacks

    /// Called when frame size changes (Pipeline → Receiver)
    public var onFrameSizeChanged: ((CGSize) -> Void)?

    /// Called when mode changes (Pipeline → Receiver)
    public var onModeChanged: ((EndoscopeViewMode) -> Void)?

    /// Called when error occurs (Pipeline → Receiver)
    public var onError: ((Error) -> Void)?

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.television.hippo", category: "RenderPipeline")

    // VideoPlayer (unified for all modes)
    private var videoPlayer: StereoVideoPlayer?

    // Helper for pixel buffer processing
    private let helper = StereoVideoPlayerHelper()

    // Current mode
    private var currentMode: EndoscopeViewMode = .rawStream

    // Track if pipeline has been initialized
    private var isInitialized: Bool = false

    // Frame counter for logging
    private var framesProcessed: Int = 0

    // MARK: - Initialization

    public init() {
        logger.info("RenderPipeline initialized (3-stage VideoPlayer architecture)")
    }

    deinit {
        logger.info("RenderPipeline deallocated")
    }

    // MARK: - Public API

    /// Configure pipeline for a specific mode
    public func configure(for mode: EndoscopeViewMode) {
        guard currentMode != mode || !isInitialized else {
            logger.info("Already configured for: \(mode.rawValue)")
            return
        }

        if !isInitialized {
            logger.info("Initial pipeline configuration: \(mode.rawValue)")
        } else {
            logger.info("Reconfiguring pipeline: \(self.currentMode.rawValue) → \(mode.rawValue)")
        }

        // Cleanup if already initialized
        if isInitialized {
            cleanupResources()
        }

        // Update mode
        currentMode = mode

        // Initialize VideoPlayer (unified for all modes)
        initializeVideoPlayer()

        // Mark as initialized
        isInitialized = true

        // Notify via callback
        onModeChanged?(mode)

        logger.info("Pipeline configured for: \(mode.rawValue)")
    }

    /// Process frame based on current mode
    public func processFrame(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        framesProcessed += 1

        switch currentMode {
        case .rawStream:
            processRawSBS(pixelBuffer, pts: pts, duration: duration)

        case .splitSBS:
            processLeftOnlyMono(pixelBuffer, pts: pts, duration: duration)

        case .stereo3D:
            processStereo3D(pixelBuffer, pts: pts, duration: duration)
        }

        // Log periodically
        if framesProcessed % 120 == 0 {
            logger.debug("Processed \(self.framesProcessed) frames in mode: \(self.currentMode.rawValue)")
        }
    }

    /// Get VideoPlayer renderer (for RealityView attachment)
    public func getVideoRenderer() -> StereoVideoPlayer? {
        return videoPlayer
    }

    /// Cleanup all resources
    public func cleanup() {
        logger.info("Cleaning up all pipeline resources...")
        cleanupResources()
        currentMode = .rawStream
        isInitialized = false
        framesProcessed = 0
        currentFrameSize = .zero
    }

    // MARK: - Resource Management

    /// Initialize VideoPlayer (unified for all modes)
    private func initializeVideoPlayer() {
        if videoPlayer == nil {
            logger.info("   ✓ Creating StereoVideoPlayer...")
            let player = StereoVideoPlayer()
            player.play()
            videoPlayer = player
            logger.info("   ✓ StereoVideoPlayer initialized and playing")
        } else {
            logger.info("   ✓ StereoVideoPlayer already exists (reusing)")
        }
    }

    /// Cleanup all resources
    private func cleanupResources() {
        logger.info("Cleaning up resources...")

        if let player = videoPlayer {
            logger.info("   ✓ Stopping VideoPlayer...")
            player.stop()
            videoPlayer = nil
        }

        framesProcessed = 0
        logger.info("Resources cleaned up")
    }

    // MARK: - Stage 1: Raw SBS Mode (가장 안전한 fallback)

    /// Process raw SBS frame
    /// Sends SBS frame directly to VideoPlayer without any processing
    /// Supports both full1080 (3840×1080) and half1080 (1920×540)
    private func processRawSBS(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        guard let player = videoPlayer else {
            if framesProcessed == 1 {
                logger.error("VideoPlayer not available in Raw SBS mode")
            }
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Update frame size (full SBS size)
        updateFrameSize(width: width, height: height, label: "Raw SBS")

        // Send raw SBS directly to VideoPlayer
        player.enqueuePixelBuffer(pixelBuffer, pts: pts, duration: duration)

        if framesProcessed == 1 {
            logger.info("✅ Raw SBS mode: Sending \(width)×\(height) directly to VideoPlayer")
        }
    }

    // MARK: - Stage 2: Left-only Mono Mode (수술실 최소 성공 라인)

    /// Process left-only mono frame
    /// Extracts left eye from SBS:
    /// - full1080: 3840×1080 → 1920×1080
    /// - half1080: 1920×540 → 960×540
    private func processLeftOnlyMono(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        guard let player = videoPlayer else {
            if framesProcessed == 1 {
                logger.error("VideoPlayer not available in Left-only Mono mode")
            }
            return
        }

        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Extract left eye only
        guard let monoBuffer = helper.makeLeftEyeMono(from: pixelBuffer) else {
            if framesProcessed == 1 {
                logger.error("Failed to extract left eye from SBS")
            }
            return
        }

        let monoWidth = CVPixelBufferGetWidth(monoBuffer)
        let monoHeight = CVPixelBufferGetHeight(monoBuffer)

        // Update frame size (mono size)
        updateFrameSize(width: monoWidth, height: monoHeight, label: "Left-only Mono")

        // Send mono buffer to VideoPlayer
        player.enqueuePixelBuffer(monoBuffer, pts: pts, duration: duration)

        if framesProcessed == 1 {
            logger.info("✅ Left-only Mono: \(srcWidth)×\(srcHeight) → \(monoWidth)×\(monoHeight)")
        }
    }

    // MARK: - Stage 3: Stereo 3D Mode (도전 과제)

    /// Process stereo 3D frame
    /// Software split: SBS → left/right tagged buffers → stereo sample buffer
    /// Supports both full1080 and half1080
    private func processStereo3D(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        guard let player = videoPlayer else {
            if framesProcessed == 1 {
                logger.error("VideoPlayer not available in Stereo 3D mode")
            }
            return
        }

        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let perEyeWidth = srcWidth / 2

        // Update frame size (per-eye)
        updateFrameSize(width: perEyeWidth, height: srcHeight, label: "Stereo 3D")

        // Create stereo sample buffer using software split
        guard let stereoSample = helper.makeStereoSampleBuffer(
            from: pixelBuffer,
            pts: pts,
            duration: duration
        ) else {
            if framesProcessed == 1 {
                logger.error("Failed to create stereo sample buffer")
            }
            return
        }

        // Enqueue to VideoPlayer
        player.enqueueSample(stereoSample)

        if framesProcessed == 1 {
            logger.info("✅ Stereo 3D: \(srcWidth)×\(srcHeight) → left/right \(perEyeWidth)×\(srcHeight)")
        }
    }

    // MARK: - Helpers

    /// Update frame size (with logging on change)
    private func updateFrameSize(width: Int, height: Int, label: String) {
        let newSize = CGSize(width: width, height: height)

        if currentFrameSize != newSize {
            let oldSize = currentFrameSize
            currentFrameSize = newSize
            logger.info("\(label) frame size: \(Int(oldSize.width))×\(Int(oldSize.height)) → \(width)×\(height)")

            // Notify via callback
            onFrameSizeChanged?(newSize)
        }
    }
}
