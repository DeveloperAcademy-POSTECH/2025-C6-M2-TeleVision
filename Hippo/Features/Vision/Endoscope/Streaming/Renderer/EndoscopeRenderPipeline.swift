//
//  EndoscopeRenderPipeline.swift
//  Hippo
//
//  Rendering pipeline for endoscope streaming
//  Manages mode-specific rendering logic and resources
//

import Foundation
import AVFoundation
import CoreVideo
import CoreMedia
import CoreImage
import os.log
import Combine

/// Manages rendering pipeline for different view modes
/// Handles resource lifecycle and frame routing
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

    // Rendering components (lazy initialized based on mode)
    private var metalRenderer: StereoVideoRenderer?
    private var videoPlayer: StereoVideoPlayer?
    private var convertingModel: ConvertingModel?

    // Current mode
    private var currentMode: EndoscopeViewMode = .stereo3D

    // Track if pipeline has been initialized at least once
    private var isInitialized: Bool = false

    // Frame counter for logging
    private var framesProcessed: Int = 0

    // CIContext for YUV → BGRA conversion (shared across modes)
    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: true
        ]
        return CIContext(options: options)
    }()

    // MARK: - Initialization

    public init() {
        logger.info("RenderPipeline initialized")
    }

    deinit {
        logger.info("RenderPipeline deallocated")
    }

    // MARK: - Public API

    /// Configure pipeline for a specific mode
    public func configure(for mode: EndoscopeViewMode) {
        // Allow configuration if mode changed OR first-time initialization
        guard currentMode != mode || !isInitialized else {
            logger.info("Already configured for: \(mode.rawValue)")
            return
        }

        if !isInitialized {
            logger.info("Initial pipeline configuration: \(mode.rawValue)")
        } else {
            logger.info("Reconfiguring pipeline: \(self.currentMode.rawValue) → \(mode.rawValue)")
        }

        // Step 1: Cleanup ALL stages (not just current mode) if already initialized
        if isInitialized {
            cleanupAllStages()
        }

        // Step 2: Update mode
        currentMode = mode

        // Step 3: Initialize new mode resources
        setupVideoPlayerIfNeeded(for: mode)
        setupMetalRendererIfNeeded(for: mode)
        setupConvertingModelIfNeeded(for: mode)

        // Step 4: Mark as initialized
        isInitialized = true

        // Step 5: Notify via callback
        onModeChanged?(mode)

        logger.info("Pipeline configured for: \(mode.rawValue)")
    }

    /// Process frame based on current mode
    public func processFrame(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        framesProcessed += 1

        switch currentMode {
        case .rawStream:
            feedRawStream(pixelBuffer)

        case .splitSBS:
            feedSplitView(pixelBuffer)

        case .stereo3D:
            feedStereo3D(pixelBuffer, pts: pts, duration: duration)
        }

        // Log periodically
        if framesProcessed % 120 == 0 {
            logger.debug("Processed \(self.framesProcessed) frames in mode: \(self.currentMode.rawValue)")
        }
    }

    /// Get Metal renderer (for RealityView attachment)
    public func getMetalRenderer() -> StereoVideoRenderer? {
        return metalRenderer
    }

    /// Get VideoPlayer renderer (for RealityView attachment)
    public func getVideoRenderer() -> StereoVideoPlayer? {
        return videoPlayer
    }

    /// Cleanup all resources
    public func cleanup() {
        logger.info("Cleaning up all pipeline resources...")
        cleanupAllStages()
        currentMode = .stereo3D // Reset to default
        isInitialized = false // Reset initialization flag
        framesProcessed = 0
        currentFrameSize = .zero
    }

    // MARK: - Resource Management

    /// Cleanup ALL stage resources (regardless of mode)
    /// Called during mode transition to ensure clean state
    private func cleanupAllStages() {
        logger.info("Cleaning up ALL stages...")

        // Cleanup Metal Renderer (Stage 1 & 2)
        if let renderer = metalRenderer {
            logger.info("   ✓ Deactivating Metal renderer...")
            renderer.deactivate()
            metalRenderer = nil
        }

        // Cleanup VideoPlayer (Stage 3)
        if let player = videoPlayer {
            logger.info("   ✓ Stopping VideoPlayer...")
            player.stop()
            videoPlayer = nil
        }

        // Cleanup ConvertingModel (Stage 3)
        if convertingModel != nil {
            logger.info("   ✓ Releasing ConvertingModel...")
            convertingModel = nil
        }

        // Reset counters
        framesProcessed = 0

        logger.info("All stages cleaned up")
    }

    /// Cleanup resources for a specific mode (legacy, prefer cleanupAllStages)
    @available(*, deprecated, message: "Use cleanupAllStages() instead")
    private func cleanupResources(for mode: EndoscopeViewMode) {
        cleanupAllStages()
    }

    private func initializeResources(for mode: EndoscopeViewMode) {
        let config = EndoscopePipelineConfig(mode: mode)

        if config.enableVideoPlayer {
            logger.info("   Creating VideoPlayer...")
            let player = StereoVideoPlayer()
            player.play()
            videoPlayer = player
        }

        if config.enableMetalRenderer {
            logger.info("   Creating Metal renderer...")
            let renderer = StereoVideoRenderer()
            renderer.activate()
            metalRenderer = renderer
        }

        if config.enableConvertingModel {
            logger.info("   Creating ConvertingModel...")
            convertingModel = ConvertingModel(stereoMetadata: .default)
        }
    }

    // MARK: - Mode-Specific Resource Setup

    /// Setup VideoPlayer if needed for Stereo 3D mode
    /// Called after cleanupAllStages(), so only handles creation
    private func setupVideoPlayerIfNeeded(for mode: EndoscopeViewMode) {
        // Only Stereo 3D mode needs VideoPlayer
        guard mode == .stereo3D else {
            return
        }

        // Create and activate VideoPlayer
        if videoPlayer == nil {
            logger.info("   ✓ Creating StereoVideoPlayer for Stereo 3D mode...")
            let player = StereoVideoPlayer()
            player.play()
            videoPlayer = player
            logger.info("   ✓ StereoVideoPlayer initialized and playing")
        } else {
            logger.info("   ✓ StereoVideoPlayer already exists (reusing)")
        }
    }

    /// Setup Metal Renderer if needed for Raw Stream or Split SBS modes
    /// Called after cleanupAllStages(), so only handles creation
    private func setupMetalRendererIfNeeded(for mode: EndoscopeViewMode) {
        // Only Raw Stream and Split SBS modes need Metal Renderer
        guard mode == .rawStream || mode == .splitSBS else {
            return
        }

        // Create and activate Metal Renderer
        if metalRenderer == nil {
            logger.info("   ✓ Creating StereoVideoRenderer for \(mode.rawValue) mode...")
            let renderer = StereoVideoRenderer()
            renderer.activate()
            metalRenderer = renderer
            logger.info("   ✓ StereoVideoRenderer initialized and activated")
        } else {
            logger.info("   ✓ StereoVideoRenderer already exists (reusing)")
        }
    }

    /// Setup ConvertingModel if needed for Stereo 3D mode
    /// Called after cleanupAllStages(), so only handles creation
    private func setupConvertingModelIfNeeded(for mode: EndoscopeViewMode) {
        // Only Stereo 3D mode needs ConvertingModel
        guard mode == .stereo3D else {
            return
        }

        // Create ConvertingModel WITHOUT recommended attributes
        // Testing: recommendedPixelBufferAttributes may cause issues with tagged buffer groups
        if convertingModel == nil {
            logger.info("   ✓ Creating ConvertingModel for Stereo 3D mode...")
            logger.info("   Using default pixel buffer attributes (testing without recommendations)")

            convertingModel = ConvertingModel(
                stereoMetadata: .default,
                recommendedPixelBufferAttributes: nil  // Test without recommended attrs
            )
            logger.info("   ✓ ConvertingModel initialized")
        } else {
            logger.info("   ✓ ConvertingModel already exists (reusing)")
        }
    }

    // MARK: - Stage 1: Raw Stream

    private func feedRawStream(_ pixelBuffer: CVPixelBuffer) {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let aspect = Double(width) / Double(height)

        // Auto-detect SBS format based on aspect ratio
        // SBS (Side-by-Side): aspect > 2.0 (e.g., 1920×540 ≈ 3.56)
        // Mono: aspect ≤ 2.0 (e.g., 1920×1080 ≈ 1.78)
        let isSBS = aspect > 2.0

        // Log only first few frames or periodically to avoid spam
        if framesProcessed <= 3 || framesProcessed % 120 == 0 {
            logger.info("Raw Stream: \(width)×\(height), aspect=\(String(format: "%.2f", aspect)), isSBS=\(isSBS)")
        }

        feedMetalRenderer(
            pixelBuffer,
            isSBS: isSBS,
            debugLabel: "Raw Stream"
        )
    }

    // MARK: - Stage 2: Split View

    private func feedSplitView(_ pixelBuffer: CVPixelBuffer) {
        // Common processing: size update + BGRA conversion + render
        // Metal renderer will split SBS internally
        feedMetalRenderer(
            pixelBuffer,
            isSBS: true,   // SBS frame (will be split)
            debugLabel: "Split View"
        )
    }

    // MARK: - Stage 3: Stereo 3D

    private func feedStereo3D(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        guard let player = videoPlayer else {
            if framesProcessed == 1 || framesProcessed % 120 == 0 {
                logger.warning("[feedStereo3D] VideoPlayer is NIL at frame \(self.framesProcessed)")
                logger.warning("[feedStereo3D] Pipeline mode: \(self.currentMode.rawValue)")
            }
            return
        }

        guard let converter = convertingModel else {
            if framesProcessed % 120 == 0 {
                logger.warning("Stereo 3D mode but ConvertingModel not initialized")
            }
            return
        }

        // Update frame size (SBS source, per-eye is half)
        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let perEyeWidth = srcWidth / 2

        updateFrameSize(width: perEyeWidth, height: srcHeight, label: "Stereo 3D")

        // TEST: Bypass ConvertingModel - send raw SBS directly
        if framesProcessed == 1 {
            logger.warning("⚠️ TEST MODE: Bypassing ConvertingModel, sending raw SBS")
        }

        player.enqueuePixelBuffer(pixelBuffer, pts: pts, duration: duration)

        if framesProcessed == 1 {
            logger.info("✅ TEST: Raw SBS frame sent to VideoPlayer")
        }

        // ORIGINAL CODE (commented out for testing):
        /*
        do {
            guard let stereoSample = try converter.process(
                pixelBuffer,
                pts: pts,
                duration: duration
            ) else {
                if framesProcessed == 1 {
                    logger.error("Failed to convert to stereo sample")
                }
                return
            }

            // Enqueue to VideoPlayer
            player.enqueueSample(stereoSample)

            if framesProcessed == 1 {
                logger.info("First stereo frame enqueued to VideoPlayer")
            }
        } catch {
            if framesProcessed == 1 {
                logger.error("ConvertingModel error: \(error.localizedDescription)")
            }
        }
        */
    }

    // MARK: - Common Helpers

    /// Common Metal rendering helper (used by Raw Stream & Split View)
    private func feedMetalRenderer(_ pixelBuffer: CVPixelBuffer, isSBS: Bool, debugLabel: String) {
        guard let renderer = metalRenderer else {
            if framesProcessed % 120 == 0 {
                logger.warning("\(debugLabel) mode but Metal renderer not initialized")
            }
            return
        }

        // Update frame size
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let displayWidth = isSBS ? (width / 2) : width

        updateFrameSize(width: displayWidth, height: height, label: debugLabel)

        // Ensure BGRA format
        let buffer = ensureBGRA(pixelBuffer) ?? pixelBuffer

        // Update renderer
        renderer.updateFrame(buffer)
    }

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

    /// Ensure pixel buffer is in BGRA format (convert if needed)
    private func ensureBGRA(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)

        // Already BGRA, return as-is
        if format == kCVPixelFormatType_32BGRA {
            return pixelBuffer
        }

        // Convert YUV → BGRA
        return convertToBGRA(pixelBuffer)
    }

    /// Convert YUV pixel buffer to BGRA
    private func convertToBGRA(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        var outPB: CVPixelBuffer?
        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &outPB
        ) == kCVReturnSuccess, let dst = outPB else {
            logger.error("Failed to create BGRA pixel buffer")
            return nil
        }

        let srcImage = CIImage(cvPixelBuffer: pixelBuffer)
        ciContext.render(srcImage, to: dst)
        return dst
    }
}
