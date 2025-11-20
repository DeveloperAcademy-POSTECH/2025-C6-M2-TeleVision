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

    // Track if pipeline is being cleaned up (prevents infinite defer loops)
    private var isCleaningUp: Bool = false

    // Frame counter for logging
    private var framesProcessed: Int = 0

    // MARK: - Frame Skip State (Real-time Performance)

    /// Processing state for splitSBS mode
    private var isProcessingSplitSBS = false
    private var latestPendingSplitSBSFrame: (CVPixelBuffer, CMTime, CMTime)?

    /// Processing state for stereo3D mode
    private var isProcessingStereo3D = false
    private var latestPendingStereo3DFrame: (CVPixelBuffer, CMTime, CMTime)?

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

        // Reset cleanup flag (ready to process frames again)
        isCleaningUp = false

        // Initialize VideoPlayer (unified for all modes)
        initializeVideoPlayer()

        // Mark as initialized
        isInitialized = true

        // Notify via callback
        onModeChanged?(mode)

        logger.info("Pipeline configured for: \(mode.rawValue)")
    }

    /// Process frame based on current mode (async to support background processing)
    public func processFrame(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) async {
        // CRITICAL: Stop processing immediately if cleanup is in progress
        let cleaningUp = await MainActor.run { isCleaningUp }
        guard !cleaningUp else {
            return
        }

        await MainActor.run {
            framesProcessed += 1
        }

        let mode = await MainActor.run { currentMode }
        switch mode {
        case .rawStream:
            await processRawSBS(pixelBuffer, pts: pts, duration: duration)

        case .splitSBS:
            await processLeftOnlyMono(pixelBuffer, pts: pts, duration: duration)

        case .stereo3D:
            await processStereo3D(pixelBuffer, pts: pts, duration: duration)
        }

        // Log periodically
        let frames = await MainActor.run { framesProcessed }
        if frames % 120 == 0 {
            logger.debug("Processed \(frames) frames in mode: \(mode.rawValue)")
        }
    }

    /// Get VideoPlayer renderer (for RealityView attachment)
    public func getVideoRenderer() -> StereoVideoPlayer? {
        return videoPlayer
    }

    /// Cleanup all resources
    public func cleanup() {
        logger.info("Cleaning up all pipeline resources...")

        // CRITICAL: Set cleanup flag FIRST to stop all incoming frames
        isCleaningUp = true

        // Clear pending frames immediately to prevent defer loops
        latestPendingSplitSBSFrame = nil
        latestPendingStereo3DFrame = nil

        // Reset processing state
        isProcessingSplitSBS = false
        isProcessingStereo3D = false

        // Now cleanup resources
        cleanupResources()

        // Reset state
        currentMode = .rawStream
        isInitialized = false
        framesProcessed = 0
        currentFrameSize = .zero

        logger.info("✅ Pipeline cleanup complete")
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

        // Cleanup helper's cached resources (VTPixelTransferSession)
        helper.cleanup()

        framesProcessed = 0
        logger.info("Resources cleaned up")
    }

    // MARK: - Stage 1: Raw SBS Mode (가장 안전한 fallback)

    /// Process raw SBS frame
    /// Sends SBS frame directly to VideoPlayer without any processing
    /// Supports both full1080 (3840×1080) and half1080 (1920×540)
    private func processRawSBS(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) async {
        let player = await MainActor.run { videoPlayer }
        let frames = await MainActor.run { framesProcessed }

        guard let player = player else {
            if frames == 1 {
                logger.error("VideoPlayer not available in Raw SBS mode")
            }
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        // Update frame size (full SBS size)
        await updateFrameSize(width: width, height: height, label: "Raw SBS")

        // Send raw SBS directly to VideoPlayer (must be on main thread)
        await MainActor.run {
            player.enqueuePixelBuffer(pixelBuffer, pts: pts, duration: duration)
        }

        if frames == 1 {
            logger.info("✅ Raw SBS mode: Sending \(width)×\(height) directly to VideoPlayer")
        }
    }

    // MARK: - Stage 2: Left-only Mono Mode (수술실 최소 성공 라인)

    /// Process left-only mono frame
    /// Extracts left eye from SBS:
    /// - full1080: 3840×1080 → 1920×1080
    /// - half1080: 1920×540 → 960×540
    /// Real-time optimized: Skips frames if processing is in progress (latest frame priority)
    private func processLeftOnlyMono(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) async {
        // Check if already processing (latest frame priority)
        let isProcessing = await MainActor.run { isProcessingSplitSBS }
        guard !isProcessing else {
            await MainActor.run {
                latestPendingSplitSBSFrame = (pixelBuffer, pts, duration)
                logger.debug("[SplitSBS] Frame queued (processing in progress)")
            }
            return
        }

        // Mark as processing
        await MainActor.run { isProcessingSplitSBS = true }

        defer {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isProcessingSplitSBS = false

                // CRITICAL: Don't process pending frames if cleanup is in progress
                guard !self.isCleaningUp else {
                    self.latestPendingSplitSBSFrame = nil
                    return
                }

                // Process pending frame if available
                if let pending = self.latestPendingSplitSBSFrame {
                    self.latestPendingSplitSBSFrame = nil
                    self.logger.debug("[SplitSBS] Processing pending frame")
                    await self.processLeftOnlyMono(pending.0, pts: pending.1, duration: pending.2)
                }
            }
        }

        // Process frame with performance measurement
        let player = await MainActor.run { videoPlayer }
        let frames = await MainActor.run { framesProcessed }

        guard let player = player else {
            if frames == 1 {
                await MainActor.run {
                    logger.error("VideoPlayer not available in Left-only Mono mode")
                }
            }
            return
        }

        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Performance measurement start
        let startTime = CFAbsoluteTimeGetCurrent()

        // Extract left eye only (runs on background with cached VTPixelTransferSession)
        guard let monoBuffer = helper.makeLeftEyeMono(from: pixelBuffer) else {
            if frames == 1 {
                await MainActor.run {
                    logger.error("Failed to extract left eye from SBS")
                }
            }
            return
        }

        // Performance measurement end
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        let monoWidth = CVPixelBufferGetWidth(monoBuffer)
        let monoHeight = CVPixelBufferGetHeight(monoBuffer)

        // Update frame size (mono size)
        await updateFrameSize(width: monoWidth, height: monoHeight, label: "Left-only Mono")

        // Send mono buffer to VideoPlayer (must be on main thread)
        await MainActor.run {
            player.enqueuePixelBuffer(monoBuffer, pts: pts, duration: duration)
        }

        // Performance logging
        await MainActor.run {
            if elapsedMs > 15.0 {
                logger.warning("[SplitSBS] Slow processing: \(String(format: "%.1f", elapsedMs))ms")
            } else if frames % 120 == 0 {
                logger.debug("[SplitSBS] Processing time: \(String(format: "%.1f", elapsedMs))ms")
            }
        }

        if frames == 1 {
            await MainActor.run {
                logger.info("✅ Left-only Mono: \(srcWidth)×\(srcHeight) → \(monoWidth)×\(monoHeight)")
            }
        }
    }

    // MARK: - Stage 3: Stereo 3D Mode (도전 과제)

    /// Process stereo 3D frame
    /// Software split: SBS → left/right tagged buffers → stereo sample buffer
    /// Supports both full1080 and half1080
    /// OPTIMIZED: Runs on background thread with cached VTPixelTransferSession
    /// Real-time optimized: Skips frames if processing is in progress (latest frame priority)
    private func processStereo3D(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) async {
        // Check if already processing (latest frame priority)
        let isProcessing = await MainActor.run { isProcessingStereo3D }
        guard !isProcessing else {
            await MainActor.run {
                latestPendingStereo3DFrame = (pixelBuffer, pts, duration)
                logger.debug("[Stereo3D] Frame queued (processing in progress)")
            }
            return
        }

        // Mark as processing
        await MainActor.run { isProcessingStereo3D = true }

        defer {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isProcessingStereo3D = false

                // CRITICAL: Don't process pending frames if cleanup is in progress
                guard !self.isCleaningUp else {
                    self.latestPendingStereo3DFrame = nil
                    return
                }

                // Process pending frame if available
                if let pending = self.latestPendingStereo3DFrame {
                    self.latestPendingStereo3DFrame = nil
                    self.logger.debug("[Stereo3D] Processing pending frame")
                    await self.processStereo3D(pending.0, pts: pending.1, duration: pending.2)
                }
            }
        }

        // Process frame with performance measurement
        let player = await MainActor.run { videoPlayer }
        let frames = await MainActor.run { framesProcessed }

        guard let player = player else {
            if frames == 1 {
                await MainActor.run {
                    logger.error("VideoPlayer not available in Stereo 3D mode")
                }
            }
            return
        }

        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let perEyeWidth = srcWidth / 2

        // Update frame size (per-eye)
        await updateFrameSize(width: perEyeWidth, height: srcHeight, label: "Stereo 3D")

        // Performance measurement start
        let startTime = CFAbsoluteTimeGetCurrent()

        // Create stereo sample buffer using software split
        // CRITICAL: This runs on BACKGROUND thread with cached VTPixelTransferSession
        // No more creating/destroying session every frame = massive performance gain
        guard let stereoSample = helper.makeStereoSampleBuffer(
            from: pixelBuffer,
            pts: pts,
            duration: duration
        ) else {
            if frames == 1 {
                await MainActor.run {
                    logger.error("Failed to create stereo sample buffer")
                }
            }
            return
        }

        // Performance measurement end
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        // Enqueue to VideoPlayer (must be on main thread)
        await MainActor.run {
            player.enqueueSample(stereoSample)
        }

        // Performance logging
        await MainActor.run {
            if elapsedMs > 15.0 {
                logger.warning("[Stereo3D] Slow processing: \(String(format: "%.1f", elapsedMs))ms")
            } else if frames % 120 == 0 {
                logger.debug("[Stereo3D] Processing time: \(String(format: "%.1f", elapsedMs))ms")
            }
        }

        if frames == 1 {
            await MainActor.run {
                logger.info("✅ Stereo 3D: \(srcWidth)×\(srcHeight) → left/right \(perEyeWidth)×\(srcHeight) [OPTIMIZED]")
            }
        }
    }

    // MARK: - Helpers

    /// Update frame size (with logging on change)
    private func updateFrameSize(width: Int, height: Int, label: String) async {
        let newSize = CGSize(width: width, height: height)
        let oldSize = await MainActor.run { currentFrameSize }

        if oldSize != newSize {
            await MainActor.run {
                currentFrameSize = newSize
                logger.info("\(label) frame size: \(Int(oldSize.width))×\(Int(oldSize.height)) → \(width)×\(height)")

                // Notify via callback
                onFrameSizeChanged?(newSize)
            }
        }
    }
}
