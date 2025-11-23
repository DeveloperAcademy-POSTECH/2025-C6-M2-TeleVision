//
//  StereoVideoPlayer.swift
//  Hippo
//
//  Dedicated stereo video player for Vision Pro
//  Separated from WebRTC receiver for clean architecture
//

@preconcurrency import AVFoundation
import CoreMedia
import os.log

/// A stereo video player that manages AVSampleBufferVideoRenderer with proper synchronization
@MainActor
public final class StereoVideoPlayer {
    /// The synchronizer that controls the underlying video renderer
    private let synchronizer = AVSampleBufferRenderSynchronizer()

    /// The video renderer that enqueues individual frames for playback
    let videoRenderer = AVSampleBufferVideoRenderer()

    /// Logger for diagnostics
    private let logger = Logger(subsystem: "com.television.hippo", category: "StereoVideoPlayer")

    /// Frame statistics
    private var framesEnqueued: Int = 0
    private var isRendererReady: Bool = false

    /// Buffer management - flush periodically to prevent memory buildup
    /// Conservative approach: only periodic flush, no aggressive emergency flush
    private let baseFlushInterval: Int = 1350  // Flush every 1350 frames (45 seconds at 30fps)
    private var framesSinceLastFlush: Int = 0

    /// Task for observing flush notifications (must be cancelled on cleanup)
    private var notificationTask: Task<Void, Never>?

    /// Pending samples buffer for Demo mode (when renderer is not ready yet)
    private var pendingSamples: [CMSampleBuffer] = []
    private let maxPendingSamples = 10  // Keep only first 10 frames if renderer is slow

    // MARK: - Initialization

    init() {
        // Add renderer to synchronizer for timing control
        synchronizer.addRenderer(videoRenderer)

        setupRenderer()

        let instanceID = String(describing: ObjectIdentifier(self))
        logger.info("StereoVideoPlayer initialized with synchronizer (id=\(instanceID))")
    }

    deinit {
        notificationTask?.cancel()
        notificationTask = nil
        let instanceID = String(describing: ObjectIdentifier(self))
        logger.info("StereoVideoPlayer DEINIT (id=\(instanceID)) - being destroyed!")
    }

    // MARK: - Public Methods

    /// Start playback
    func play() {
        synchronizer.setRate(1.0, time: .zero)
        logger.info("Playback started (rate: 1.0)")
    }

    /// Pause playback
    func pause() {
        synchronizer.rate = 0.0
        logger.info("Playback paused")
    }

    /// Stop playback and flush renderer
    func stop() {
        synchronizer.rate = 0.0
        videoRenderer.stopRequestingMediaData()
        videoRenderer.flush()

        // Cancel notification observer task to prevent memory leak
        notificationTask?.cancel()
        notificationTask = nil

        // Clear pending samples buffer
        if !pendingSamples.isEmpty {
            logger.info("   Clearing \(self.pendingSamples.count) pending samples")
            pendingSamples.removeAll()
        }

        framesEnqueued = 0
        framesSinceLastFlush = 0
        isRendererReady = false

        logger.info("Playback stopped and renderer flushed")
    }

    /// Enqueue a stereo-tagged sample buffer for rendering
    /// - Parameter sample: CMSampleBuffer with stereo tags (from ConvertingModel)
    func enqueueSample(_ sample: CMSampleBuffer) {
        // Check renderer status first
        let status = videoRenderer.status
        if status == .failed {
            if framesEnqueued == 0 {
                logger.error("❌ Renderer status is FAILED before first frame")
                if let error = videoRenderer.error {
                    logger.error("   Error: \(error.localizedDescription)")
                }
            }
            return
        }

        // Check if ready for more data
        let isReady = videoRenderer.isReadyForMoreMediaData
        if !isReady {
            if framesEnqueued == 0 {
                logger.warning("⚠️ Renderer not ready for first frame (buffering for retry)")

                // Buffer this sample for retry when renderer becomes ready
                if pendingSamples.count < maxPendingSamples {
                    pendingSamples.append(sample)
                    logger.info("   📦 Buffered frame #\(self.pendingSamples.count) (will enqueue when ready)")
                }
            }
            return
        }

        // Renderer is ready - flush any pending samples first
        if !pendingSamples.isEmpty {
            logger.info("🔄 Renderer ready! Flushing \(self.pendingSamples.count) pending samples...")
            for (index, pendingSample) in pendingSamples.enumerated() {
                videoRenderer.enqueue(pendingSample)
                framesEnqueued += 1
                logger.info("   ✓ Enqueued pending frame #\(index + 1)")
            }
            pendingSamples.removeAll()
            logger.info("✅ All pending samples flushed")
        }

        // Log first frame details
        if framesEnqueued == 0 {
            if let formatDesc = CMSampleBufferGetFormatDescription(sample) {
                let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
                logger.info("📦 First sample buffer:")
                logger.info("   Dimensions: \(dimensions.width)×\(dimensions.height)")
                logger.info("   Renderer status: \(status.rawValue) (0=unknown, 1=ready, 2=failed)")
                logger.info("   Ready for data: \(isReady)")
            }
        }

        // Enqueue to renderer
        videoRenderer.enqueue(sample)
        framesEnqueued += 1
        framesSinceLastFlush += 1

        // Log first frame success
        if framesEnqueued == 1 {
            logger.info("✅ First stereo frame enqueued to AVSampleBufferVideoRenderer")
            isRendererReady = true
        }

        // Conservative periodic buffer flush
        if framesSinceLastFlush >= baseFlushInterval {
            videoRenderer.flush()
            framesSinceLastFlush = 0
            logger.info("🧹 Periodic buffer flush at frame \(self.framesEnqueued) (45s interval)")
        }
    }

    /// Enqueue a raw pixel buffer (will be wrapped in CMSampleBuffer with stereo hints)
    /// - Parameters:
    ///   - pixelBuffer: CVPixelBuffer containing full SBS frame
    ///   - pts: Presentation timestamp
    ///   - duration: Frame duration
    func enqueuePixelBuffer(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        // Just enqueue immediately - AVSampleBufferVideoRenderer handles buffering internally
        enqueuePixelBufferImmediate(pixelBuffer, pts: pts, duration: duration)
    }

    // MARK: - Private Methods

    private func setupRenderer() {
        // Request media data to activate the renderer
        videoRenderer.requestMediaDataWhenReady(on: .main) { [weak self] in
            guard let self = self else { return }

            // Already on main queue, no need for Task
            // Renderer is now ready
            if !self.isRendererReady {
                self.isRendererReady = true
                self.logger.info("🎬 AVSampleBufferVideoRenderer is ready (requestMediaDataWhenReady callback)")
                self.logger.info("   Renderer can now accept frames for display")
            }
        }

        // Cancel previous notification task if exists
        notificationTask?.cancel()

        // Observe flush notifications - store task for proper cleanup
        notificationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            for await _ in NotificationCenter.default.notifications(
                named: AVSampleBufferVideoRenderer.requiresFlushToResumeDecodingDidChangeNotification,
                object: self.videoRenderer
            ) {
                self.logger.info("Flushing renderer to resume decoding")
                self.videoRenderer.flush()
            }
        }

        logger.info("AVSampleBufferVideoRenderer configured")
    }

    private func enqueuePixelBufferImmediate(_ pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        // Create format description
        var formatDesc: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )

        guard status == noErr, let formatDesc else {
            logger.error("Failed to create format description: \(status)")
            return
        }

        // CRITICAL FIX: DO NOT add HeroEye attachment for 2D content (Raw/Split SBS)
        // HeroEye is ONLY for stereo 3D content (CMTaggedBufferGroup)
        // Adding HeroEye to 2D mono buffers causes FigVideoQueue err=-12080 crash
        // Raw SBS and Split SBS are both 2D content and should not have stereo hints

        // Create timing info
        var timing = CMSampleTimingInfo(
            duration: duration.isValid ? duration : CMTime(value: 1, timescale: 60),
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        // Create sample buffer
        var sampleBuffer: CMSampleBuffer?
        let sbStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )

        guard sbStatus == noErr, let sb = sampleBuffer else {
            logger.error("Failed to create sample buffer: \(sbStatus)")
            return
        }

        // Set display immediately - synchronizer timing doesn't work with synthetic PTS
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) {
            let arr = attachments as NSArray
            if let dict = arr.firstObject as? NSMutableDictionary {
                dict[kCMSampleAttachmentKey_DisplayImmediately] = true
                dict[kCMSampleAttachmentKey_DoNotDisplay] = false
            }
        }

        videoRenderer.enqueue(sb)
        framesEnqueued += 1
        framesSinceLastFlush += 1

        if framesEnqueued == 1 {
            logger.info("First frame enqueued")
        } else if framesEnqueued % 60 == 0 {
            logger.debug("Enqueued \(self.framesEnqueued) frames")
        }

        // Conservative periodic buffer flush
        if framesSinceLastFlush >= baseFlushInterval {
            videoRenderer.flush()
            framesSinceLastFlush = 0
            logger.info("🧹 Periodic buffer flush at frame \(self.framesEnqueued) (45s interval)")
        }
    }
}
