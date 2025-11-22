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

    // Track if mode change is in progress (prevents frame enqueue during view transition)
    private var isModeChanging: Bool = false

    // Frame counter for logging (resets periodically to prevent overflow)
    private var framesProcessed: Int = 0
    private var framesSkipped: Int = 0  // Track skipped frames for backpressure monitoring
    private let frameCounterResetInterval: Int = 18000  // Reset every 18000 frames (10 minutes at 30fps)

    // Synthetic PTS generator (to fix broken LiveKit timestamps)
    private var syntheticPTS: CMTime? = nil  // Will be initialized to CACurrentMediaTime() on first frame
    private let frameInterval = CMTime(value: 1, timescale: 30)  // 30 fps = 33.33ms per frame (matches Mac encoder)

    // Debug counter for synthetic PTS validation
    private var debugFrameCount: Int = 0

    // Latency drift monitoring (tracks if rendering is falling behind PTS timeline)
    private var lastEnqueueRealTime: CFTimeInterval? = nil  // Real wall-clock time of last enqueue
    private var latencyDriftMs: Double = 0.0  // Current drift between PTS and real time (ms)
    private let latencyCheckInterval: Int = 300  // Check every 300 frames (10 seconds at 30fps)
    private let maxAcceptableLatencyMs: Double = 200.0  // Flush if drift exceeds 200ms

    // Live mode correction (aggressive frame dropping for real-time priority)
    private var consecutiveDriftWarnings: Int = 0  // Track how many checks in a row exceeded threshold
    private let maxConsecutiveDriftBeforeFlush: Int = 2  // Flush after 2 consecutive drift warnings

    // MARK: - Frame Processing State

    // Note: Frame skip logic removed - AVSampleBufferVideoRenderer handles buffering internally
    // All frames are now enqueued directly for smoother playback
    // Backpressure control added via isReadyForMoreMediaData

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
            // Log current PTS before mode switch
            if let pts = syntheticPTS {
                let ptsSeconds = CMTimeGetSeconds(pts)
                logger.info("🎯 Mode switch: Preserving PTS timeline at \(String(format: "%.3f", ptsSeconds))s")
            }
            // Log VideoPlayer recreation (to prevent RealityKit conflicts)
            if videoPlayer != nil {
                logger.info("🎬 VideoPlayer will be recreated (RealityKit compatibility)")
            }
        }

        // Cleanup if already initialized (preserves VideoPlayer + syntheticPTS + VTSession)
        if isInitialized {
            cleanupResources()
        }

        // Update mode
        currentMode = mode

        // Reset cleanup flag (ready to process frames again)
        isCleaningUp = false

        // Initialize VideoPlayer (unified for all modes - reuses existing if available)
        initializeVideoPlayer()

        // Mark as initialized
        isInitialized = true

        // Notify via callback
        onModeChanged?(mode)

        logger.info("Pipeline configured for: \(mode.rawValue)")
    }

    /// Process frame based on current mode (async to support background processing)
    public func processFrame(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) async {
        // CRITICAL: Stop processing immediately if cleanup or mode change is in progress
        let (cleaningUp, modeChanging) = await MainActor.run { (isCleaningUp, isModeChanging) }
        guard !cleaningUp && !modeChanging else {
            if modeChanging {
                await MainActor.run {
                    framesSkipped += 1
                    if framesSkipped <= 5 {
                        logger.debug("⏸️ Frame skipped during mode transition (#\(self.framesSkipped))")
                    }
                }
            }
            return
        }

        await MainActor.run {
            framesProcessed += 1

            // Periodic counter reset to prevent unbounded growth
            if framesProcessed >= frameCounterResetInterval {
                logger.info("🔄 Resetting frame counters (processed: \(self.framesProcessed), skipped: \(self.framesSkipped))")
                framesProcessed = 0
                framesSkipped = 0
            }
        }

        // DEBUG: Log timing info for first 10 frames (original timestamps)
        let frames = await MainActor.run { framesProcessed }
        if frames <= 10 {
            let ptsSeconds = CMTimeGetSeconds(pts)
            let durationSeconds = CMTimeGetSeconds(duration)
            logger.info("⏱️ Frame #\(frames): LiveKit PTS=\(String(format: "%.3f", ptsSeconds))s, duration=\(String(format: "%.3f", durationSeconds))s")
        }

        // CRITICAL FIX: Generate synthetic PTS to work around broken LiveKit timestamps
        // LiveKit often sends PTS discontinuities and negative durations which break AVSampleBufferVideoRenderer
        // Start from CACurrentMediaTime() to avoid dropping frames as "too old"
        // IMPORTANT: syntheticPTS is preserved across mode switches to prevent judder
        let (fixedPTS, fixedDuration) = await MainActor.run { [self] () -> (CMTime, CMTime) in
            // Initialize on first frame to current media time (only on session start)
            // Mode switching preserves existing PTS timeline
            if self.syntheticPTS == nil {
                let currentMediaTime = CACurrentMediaTime()
                self.syntheticPTS = CMTime(seconds: currentMediaTime, preferredTimescale: 30)
                self.logger.info("🎬 Initialized synthetic PTS to CACurrentMediaTime: \(String(format: "%.3f", currentMediaTime))s")
                self.logger.info("🎯 Frame interval set to \(String(format: "%.3f", CMTimeGetSeconds(self.frameInterval)))s (30 fps)")
                self.logger.info("✅ PTS timeline will be preserved across mode switches")
            }

            let currentPTS = self.syntheticPTS!
            self.syntheticPTS = CMTimeAdd(self.syntheticPTS!, self.frameInterval)

            // Debug log for first 5 frames to verify 30fps interval
            if self.debugFrameCount < 5 {
                let ptsSeconds = CMTimeGetSeconds(currentPTS)
                let intervalSeconds = CMTimeGetSeconds(self.frameInterval)
                self.logger.info("🎯 Synthetic PTS debug #\(self.debugFrameCount): pts=\(String(format: "%.3f", ptsSeconds))s, interval=\(String(format: "%.3f", intervalSeconds))s")
                self.debugFrameCount += 1
            }

            if frames <= 10 {
                let syntheticSeconds = CMTimeGetSeconds(currentPTS)
                self.logger.info("   → Using synthetic PTS=\(String(format: "%.3f", syntheticSeconds))s, duration=\(String(format: "%.3f", CMTimeGetSeconds(self.frameInterval)))s")
            }

            return (currentPTS, self.frameInterval)
        }

        let mode = await MainActor.run { currentMode }
        switch mode {
        case .rawStream:
            await processRawSBS(pixelBuffer, pts: fixedPTS, duration: fixedDuration)

        case .splitSBS:
            await processLeftOnlyMono(pixelBuffer, pts: fixedPTS, duration: fixedDuration)

        case .stereo3D:
            await processStereo3D(pixelBuffer, pts: fixedPTS, duration: fixedDuration)
        }

        // Log periodically
        if frames % 120 == 0 {
            logger.debug("Processed \(frames) frames in mode: \(mode.rawValue)")
        }

        // Monitor latency drift (check if rendering is falling behind PTS timeline)
        await checkLatencyDrift(fixedPTS: fixedPTS, frameCount: frames)
    }

    /// Monitor latency drift between synthetic PTS and real-time processing
    /// Detects if rendering is falling behind and accumulating delay
    /// LIVE MODE: Automatically triggers recovery when drift exceeds threshold
    private func checkLatencyDrift(fixedPTS: CMTime, frameCount: Int) async {
        await MainActor.run { [self] in
            let currentRealTime = CACurrentMediaTime()

            // Track enqueue real-time
            if let lastTime = self.lastEnqueueRealTime {
                // Calculate expected PTS progression vs actual real-time progression
                let ptsSeconds = CMTimeGetSeconds(fixedPTS)
                let realTimeDelta = currentRealTime - lastTime
                let expectedFrameInterval = CMTimeGetSeconds(self.frameInterval)

                // Drift = how much we're behind (positive = lagging, negative = ahead)
                let drift = realTimeDelta - expectedFrameInterval
                self.latencyDriftMs += drift * 1000.0  // Accumulate drift in ms

                // Periodic drift check and reporting
                if frameCount % self.latencyCheckInterval == 0 {
                    let isDrifting = abs(self.latencyDriftMs) > self.maxAcceptableLatencyMs

                    if isDrifting {
                        self.consecutiveDriftWarnings += 1
                        self.logger.warning("⏱️ Latency drift detected (\(self.consecutiveDriftWarnings)/\(self.maxConsecutiveDriftBeforeFlush)): \(String(format: "%.1f", self.latencyDriftMs))ms (threshold: \(self.maxAcceptableLatencyMs)ms)")
                        self.logger.warning("   Real-time rendering is falling behind synthetic PTS timeline")

                        // LIVE MODE: Trigger recovery if drift persists
                        if self.consecutiveDriftWarnings >= self.maxConsecutiveDriftBeforeFlush {
                            self.logger.warning("🚨 LIVE MODE: Persistent drift detected, triggering recovery...")
                            self.recoverFromLatencyDrift()
                            self.consecutiveDriftWarnings = 0  // Reset after recovery
                        }
                    } else {
                        // Drift is within acceptable range - reset warning counter
                        if self.consecutiveDriftWarnings > 0 {
                            self.logger.info("✅ Latency recovered: \(String(format: "%.1f", self.latencyDriftMs))ms (drift warnings reset)")
                        } else {
                            self.logger.debug("✅ Latency drift: \(String(format: "%.1f", self.latencyDriftMs))ms (within acceptable range)")
                        }
                        self.consecutiveDriftWarnings = 0
                    }

                    // Reset accumulator to prevent unbounded growth
                    self.latencyDriftMs = 0.0
                }
            }

            self.lastEnqueueRealTime = currentRealTime
        }
    }

    /// Recover from latency drift by flushing buffers and adjusting PTS timeline
    /// LIVE MODE STRATEGY: Prioritize real-time display over buffered playback
    /// - Flush videoRenderer to drop old frames
    /// - Adjust syntheticPTS to catch up to current time
    /// This implements "surgical monitor" behavior: always show latest frame, drop old ones
    private func recoverFromLatencyDrift() {
        guard let player = videoPlayer else {
            logger.error("Cannot recover from drift: VideoPlayer not available")
            return
        }

        logger.warning("🔧 LIVE MODE RECOVERY:")
        logger.warning("   Step 1: Flushing videoRenderer buffer (dropping old frames)...")

        // STEP 1: Flush renderer buffer to clear accumulated frames
        player.videoRenderer.flush()

        logger.warning("   ✓ Buffer flushed")

        // STEP 2: Adjust syntheticPTS to catch up to current real time
        // This prevents further drift accumulation by resetting baseline
        let currentMediaTime = CACurrentMediaTime()
        let oldPTS = syntheticPTS
        syntheticPTS = CMTime(seconds: currentMediaTime, preferredTimescale: 30)

        if let oldPTS = oldPTS {
            let oldSeconds = CMTimeGetSeconds(oldPTS)
            let gap = currentMediaTime - oldSeconds
            logger.warning("   Step 2: Adjusting PTS baseline:")
            logger.warning("      Old PTS: \(String(format: "%.3f", oldSeconds))s")
            logger.warning("      New PTS: \(String(format: "%.3f", currentMediaTime))s")
            logger.warning("      Gap closed: \(String(format: "%.3f", gap))s (\(String(format: "%.0f", gap * 1000))ms)")
        }

        logger.warning("   ✓ PTS timeline adjusted to current time")
        logger.warning("✅ LIVE MODE RECOVERY COMPLETE")
        logger.warning("   Next frames will be displayed in real-time without buffering delay")
    }

    /// Get VideoPlayer renderer (for RealityView attachment)
    public func getVideoRenderer() -> StereoVideoPlayer? {
        return videoPlayer
    }

    /// Begin mode change (blocks frame processing until complete)
    public func beginModeChange() {
        isModeChanging = true
        logger.info("⏸️ Mode change started - frame processing paused")
    }

    /// Complete mode change (resumes frame processing)
    public func completeModeChange() {
        isModeChanging = false
        logger.info("▶️ Mode change complete - frame processing resumed")
    }

    /// Cleanup all resources (called when stopping/disconnecting streaming session)
    /// IMPORTANT: This is for complete session teardown, NOT mode switching
    public func cleanup() {
        logger.info("Cleaning up all pipeline resources (complete session teardown)...")

        // CRITICAL: Set cleanup flag FIRST to stop all incoming frames
        isCleaningUp = true

        // Complete teardown - stop and release VideoPlayer
        if let player = videoPlayer {
            logger.info("   ✓ Stopping and releasing VideoPlayer...")
            player.stop()
            videoPlayer = nil
        }

        // Complete teardown - cleanup VTPixelTransferSession
        logger.info("   ✓ Releasing VTPixelTransferSession...")
        helper.cleanup()

        // Reset state
        currentMode = .rawStream
        isInitialized = false
        framesProcessed = 0
        framesSkipped = 0
        currentFrameSize = .zero

        // CRITICAL: Only reset syntheticPTS on complete session teardown
        // Mode switching should preserve PTS timeline to prevent judder
        syntheticPTS = nil  // Reset synthetic PTS timeline (complete session end)
        debugFrameCount = 0  // Reset debug counter

        // Reset latency drift tracking
        lastEnqueueRealTime = nil
        latencyDriftMs = 0.0
        consecutiveDriftWarnings = 0

        logger.info("✅ Pipeline cleanup complete (all resources released)")
    }

    // MARK: - Resource Management

    /// Initialize VideoPlayer (unified for all modes)
    /// CRITICAL: Always creates a new VideoPlayer to prevent RealityKit VideoPlayerComponent conflicts
    private func initializeVideoPlayer() {
        // VideoPlayer should always be nil here (cleaned up in cleanupResources)
        // But add defensive check just in case
        if videoPlayer != nil {
            logger.warning("⚠️ VideoPlayer already exists during initialization - this shouldn't happen!")
            videoPlayer?.stop()
            videoPlayer = nil
        }

        logger.info("   ✓ Creating new StereoVideoPlayer...")
        let player = StereoVideoPlayer()
        player.play()
        videoPlayer = player
        logger.info("   ✓ StereoVideoPlayer initialized and playing")
    }

    /// Cleanup resources for mode switching (called during configure())
    /// CRITICAL FIX: VideoPlayer must be recreated to avoid RealityKit VideoPlayerComponent conflicts
    /// VTSession and PTS timeline are preserved for performance and smoothness
    private func cleanupResources() {
        logger.info("Cleaning up resources for mode switch...")

        // CRITICAL FIX: Recreate VideoPlayer to prevent RealityKit conflicts
        // Issue: Same AVSampleBufferVideoRenderer being attached to multiple VideoPlayerComponents
        // causes FigVideoQueue err=-12080 and prevents rendering to screen
        // Trade-off: 1-2 frame backpressure on mode switch vs crashes and blank screen
        if let player = videoPlayer {
            logger.info("   ✓ Stopping and releasing VideoPlayer for mode switch...")
            player.stop()
            videoPlayer = nil  // Will be recreated in initializeVideoPlayer()
        }

        // ✅ KEEP: VTPixelTransferSession cache (resolution-aware, no conflict with RealityKit)
        // Keeping cached session prevents:
        // 1. Session re-creation overhead (first frame 20+ms delay)
        // 2. GPU resource reallocation
        // VTPixelTransferSession is reusable across all modes (Raw/Split/Stereo)
        // helper.cleanup()  // ← DO NOT call this during mode switch

        // Reset frame counters (pipeline + helper debug logging)
        framesProcessed = 0
        debugFrameCount = 0
        helper.resetFrameCounters()  // Reset helper's mono/stereo frame counters to re-enable debug logs

        // Reset latency drift accumulator and warnings (but keep lastEnqueueRealTime for continuity)
        latencyDriftMs = 0.0
        consecutiveDriftWarnings = 0  // Reset warnings on mode switch

        // ✅ KEEP: synthetic PTS timeline preserved across mode switches
        // Mode switching preserves PTS timeline to prevent discontinuity/judder
        // syntheticPTS will only be reset in cleanup() (complete session teardown)

        logger.info("✅ Mode switch cleanup complete (VideoPlayer recreated, VTSession + PTS preserved)")
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

        // DEBUG: Verify source buffer has no CleanAperture (first 3 frames only)
        if frames <= 3 {
            let hasCleanAperture = CVBufferGetAttachment(pixelBuffer, kCVImageBufferCleanApertureKey, nil) != nil
            logger.info("🔍 [Raw Frame #\(frames)] Source buffer CleanAperture exists = \(hasCleanAperture) (should be false)")
        }

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
    private func processLeftOnlyMono(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) async {
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

        // Check if renderer is ready for more data (backpressure control)
        let isReady = await MainActor.run { player.videoRenderer.isReadyForMoreMediaData }
        guard isReady else {
            // Renderer is busy, skip this frame to prevent queue buildup
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.framesSkipped += 1
                if self.framesSkipped % 30 == 0 || self.framesSkipped < 10 {
                    let skipRate = Double(self.framesSkipped) / Double(frames) * 100
                    self.logger.warning("[SplitSBS] Renderer backpressure: \(self.framesSkipped) frames skipped (\(String(format: "%.1f", skipRate))%)")
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
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.framesSkipped += 1
                // Log all failures, not just the first one
                if self.framesSkipped % 30 == 0 || self.framesSkipped < 10 {
                    self.logger.error("[SplitSBS] Failed to extract left eye (frame #\(frames), \(self.framesSkipped) failures)")
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
    private func processStereo3D(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) async {
        let player = await MainActor.run { videoPlayer }
        let frames = await MainActor.run { framesProcessed }

        // DEBUG: Log first 10 frames only
        if frames <= 10 {
            logger.info("🔍 [Stereo3D] Frame #\(frames) - START processing")
        }

        guard let player = player else {
            if frames == 1 {
                logger.error("❌ [Stereo3D] VideoPlayer not available")
            }
            return
        }

        // Check if renderer is ready for more data (backpressure control)
        let isReady = await MainActor.run { player.videoRenderer.isReadyForMoreMediaData }

        if frames <= 10 {
            logger.debug("🔍 [Stereo3D] Frame #\(frames) - Renderer ready: \(isReady)")
        }

        guard isReady else {
            // Renderer is busy, skip this frame to prevent queue buildup
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.framesSkipped += 1
                // Log backpressure periodically
                if self.framesSkipped % 30 == 0 || self.framesSkipped < 5 {
                    let skipRate = Double(self.framesSkipped) / Double(frames) * 100
                    self.logger.warning("[Stereo3D] Backpressure: \(self.framesSkipped) frames skipped (\(String(format: "%.1f", skipRate))%)")
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

        if frames <= 10 {
            logger.debug("🔍 [Stereo3D] Frame #\(frames) - Creating stereo sample buffer...")
        }

        guard let stereoSample = helper.makeStereoSampleBuffer(
            from: pixelBuffer,
            pts: pts,
            duration: duration
        ) else {
            // Log failures periodically
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.framesSkipped += 1
                if self.framesSkipped % 30 == 0 || self.framesSkipped < 5 {
                    self.logger.error("❌ [Stereo3D] makeStereoSampleBuffer failed (frame #\(frames), \(self.framesSkipped) failures)")
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

        if frames == 1 {
            await MainActor.run {
                logger.info("✅ [Stereo3D] Frame #\(frames) - First frame enqueued")
            }
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
