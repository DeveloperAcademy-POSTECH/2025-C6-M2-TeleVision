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

    // MARK: - Initialization

    init() {
        // Add renderer to synchronizer for timing control
        synchronizer.addRenderer(videoRenderer)

        setupRenderer()

        logger.info("StereoVideoPlayer initialized with synchronizer")
    }

    deinit {
        logger.info("StereoVideoPlayer DEINIT - being destroyed!")
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

        framesEnqueued = 0
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
                logger.warning("⚠️ Renderer not ready for first frame (will retry)")
            }
            return
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

        // Log first frame success
        if framesEnqueued == 1 {
            logger.info("✅ First stereo frame enqueued to AVSampleBufferVideoRenderer")
            isRendererReady = true
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

            Task { @MainActor [weak self] in
                guard let self = self else { return }

                // Renderer is now ready
                if !self.isRendererReady {
                    self.isRendererReady = true
                    self.logger.info("AVSampleBufferVideoRenderer is ready")
                }
            }
        }

        // Observe flush notifications
        Task { @MainActor [weak self] in
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

        // Add stereo hint (Hero Eye = Left)
        CMSetAttachment(
            formatDesc,
            key: kCMFormatDescriptionExtension_HeroEye as CFString,
            value: kCMFormatDescriptionHeroEye_Left as CFTypeRef,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )

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

        // Set display immediately flag
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) {
            let arr = attachments as NSArray
            if let dict = arr.firstObject as? NSMutableDictionary {
                dict[kCMSampleAttachmentKey_DisplayImmediately] = true
                dict[kCMSampleAttachmentKey_DoNotDisplay] = false
            }
        }

        videoRenderer.enqueue(sb)
        framesEnqueued += 1

        if framesEnqueued == 1 {
            logger.info("First frame enqueued")
        } else if framesEnqueued % 60 == 0 {
            logger.debug("Enqueued \(self.framesEnqueued) frames")
        }
    }
}
