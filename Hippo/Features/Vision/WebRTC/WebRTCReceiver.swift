//
//  WebRTCReceiver.swift
//  Hippo
//
//  WebRTC receiver for Vision Pro
//  Mac (Sender) → Vision Pro (Receiver)
//

import Foundation
import CoreVideo
import CoreMedia
import AVFoundation
import os.log
import LiveKitWebRTC
import Combine
import CoreImage

// MARK: - WebRTC Receiver

@MainActor
public final class WebRTCReceiver: NSObject, ObservableObject {

    @Published public var isConnected: Bool = false
    @Published public var currentFrame: CVPixelBuffer?
    @Published public var stats: ReceiverStats = ReceiverStats()
    @Published public var currentFrameSize: CGSize = .zero  // Track current per-eye frame size

    // Path A (single-stream) renderer for RealityKit VideoMaterial with stereo tagging
    public let stereoRenderer = AVSampleBufferVideoRenderer()

    // Path B (stereo Metal) renderer - Legacy RealityKit approach (deprecated, use Path A instead)
    public let stereoMetalRenderer = StereoVideoRenderer()

    // Optional: legacy converting model for tagged stereo CMSampleBuffer (kept for experimentation)
    private var convertingModel: ConvertingModel?

    // I420 buffer converter for non-CVPixelBuffer frames
    private var i420Converter: I420BufferConverter?

    private let logger = Logger(subsystem: "com.television.hippo", category: "WebRTCReceiver")

    private var peerConnectionFactory: LKRTCPeerConnectionFactory!
    private var peerConnection: LKRTCPeerConnection?
    private var remoteVideoTrack: LKRTCVideoTrack?

    private var signalingClient: SignalingClient?
    public private(set) var signalingServerURL: URL

    private var statsTimer: Timer?
    private var framesReceived: Int = 0

    // Track last timestamp to compute duration
    private var lastPTS: CMTime?

    // Frame skip counter for VideoPlayer path (to reduce CPU usage)
    private var videoPlayerFrameCounter: UInt64 = 0

    // MARK: Remote candidate queueing

    private var pendingRemoteCandidates: [LKRTCIceCandidate] = []
    private var remoteDescriptionSet: Bool = false

    // MARK: Prevent multiple initialization
    private var isInitialized: Bool = false
    private static var globalInitCount: Int = 0
    private static let initLock = NSLock()

    // MARK: Log throttling
    private var hasLoggedRendererReady: Bool = false
    private var hasLoggedNoTarget: Bool = false
    private var framesEnqueuedCount: Int = 0

    // Last frame to replay once target attaches (optional)
    private var lastEnqueuePixelBuffer: CVPixelBuffer?
    private var lastEnqueuePTS: CMTime = .zero
    private var lastEnqueueDuration: CMTime = CMTime(value: 1, timescale: 60)

    // Track if renderer is actually ready
    private var isRendererReady: Bool = false

    // Rendering path selection
    public enum RenderPath {
        case metal      // Path B: StereoVideoRenderer (for stereoPlanes/mono)
        case videoPlayer // Path A: AVSampleBufferVideoRenderer (for stereoVideo)
    }
    private var currentRenderPath: RenderPath = .videoPlayer  // Default to VideoPlayer path

    // MARK: CIContext for YUV -> BGRA conversion (for Metal renderer path)
    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: true
        ]
        return CIContext(options: options)
    }()

    public init(signalingServerURL: URL = URL(string: "ws://127.0.0.1:8080")!) {
        self.signalingServerURL = signalingServerURL
        super.init()
    }

    /// Set rendering path (Path A: VideoPlayerComponent or Path B: Metal)
    public func setRenderPath(_ path: RenderPath) {
        // Skip if already on this path
        guard currentRenderPath != path else {
            logger.info("ℹ️ Already on render path: \(path == .metal ? "Metal" : "VideoPlayer")")
            return
        }

        let oldPath = currentRenderPath
        currentRenderPath = path

        // Cleanup previous renderer
        switch oldPath {
        case .videoPlayer:
            // Flush AVSampleBufferVideoRenderer
            logger.info("🧹 Cleaning up VideoPlayerComponent renderer...")
            stereoRenderer.flush()
            stereoRenderer.stopRequestingMediaData()
            isRendererReady = false
            lastEnqueuePixelBuffer = nil

        case .metal:
            // Deactivate StereoVideoRenderer
            logger.info("🧹 Deactivating StereoVideoRenderer...")
            stereoMetalRenderer.deactivate()
        }

        // Prepare new renderer
        switch path {
        case .videoPlayer:
            logger.info("🔧 Activating VideoPlayerComponent renderer...")
            videoPlayerFrameCounter = 0  // Reset frame counter
            framesEnqueuedCount = 0  // Reset enqueued counter
            setupStereoRenderer()
            logger.info("   Renderer status after setup: \(self.stereoRenderer.status.rawValue)")
            logger.info("   Ready for data: \(self.stereoRenderer.isReadyForMoreMediaData)")

        case .metal:
            logger.info("🔧 Activating StereoVideoRenderer...")
            stereoMetalRenderer.activate()
        }

        let pathName = path == .metal ? "Path B (StereoVideoRenderer)" : "Path A (VideoPlayerComponent)"
        logger.info("🔄 Render path switched to: \(pathName)")
    }

    /// Update the signaling server URL (requires restart)
    public func updateSignalingServer(url: URL) async throws {
        logger.info("🔄 WebRTCReceiver: Updating signaling server URL to: \(url.absoluteString)")

        // Stop current connection
        logger.info("   Stopping existing connection...")
        await stop()

        // Update URL
        signalingServerURL = url
        logger.info("   URL updated, starting WebRTC...")

        // Restart with new URL
        try await start()
        logger.info("   ✅ WebRTC started successfully")
    }

    public func start() async throws {
        guard !isInitialized else {
            logger.warning("⚠️ WebRTC Receiver already started, skipping...")
            return
        }

        logger.info("🚀 WebRTC Receiver starting...")

        // Keep legacy converting model available (optional)
        convertingModel = ConvertingModel(stereoMetadata: .default)
        logger.info("✅ ConvertingModel initialized (optional)")

        // Initialize I420 buffer converter
        i420Converter = I420BufferConverter()
        logger.info("✅ I420BufferConverter initialized")

        // Configure AVSampleBufferVideoRenderer (Path A)
        setupStereoRenderer()

        // Thread-safe global initialization
        Self.initLock.lock()
        defer { Self.initLock.unlock() }

        if Self.globalInitCount == 0 {
            logger.info("🔧 Performing WebRTC global initialization...")
            LKRTCInitializeSSL()
            LKRTCSetupInternalTracer()
            Self.globalInitCount += 1
            logger.info("✅ WebRTC global initialization complete (count: \(Self.globalInitCount))")
        } else {
            logger.info("ℹ️ WebRTC already globally initialized (count: \(Self.globalInitCount)), reusing...")
        }

        let encoderFactory = LKRTCDefaultVideoEncoderFactory()
        // Use HEVC decoder factory for better compression
        let decoderFactory = HEVCVideoDecoderFactory()

        peerConnectionFactory = LKRTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        logger.info("✅ Peer connection factory created with HEVC decoder support")

        let rtcConfig = LKRTCConfiguration()
        rtcConfig.sdpSemantics = .unifiedPlan
        let stunServer = LKRTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"])
        rtcConfig.iceServers = [stunServer]

        let constraints = LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        guard let peerConnection = peerConnectionFactory.peerConnection(
            with: rtcConfig,
            constraints: constraints,
            delegate: self
        ) else {
            throw ReceiverError.initializationFailed("Failed to create peer connection")
        }

        self.peerConnection = peerConnection

        try startSignaling()

        isInitialized = true
        logger.info("✅ WebRTC Receiver initialized")
    }

    public func stop() async {
        guard isInitialized else {
            logger.warning("⚠️ WebRTC Receiver not initialized, skipping stop...")
            return
        }

        logger.info("🛑 WebRTC Receiver stopping...")
        statsTimer?.invalidate()
        peerConnection?.close()
        signalingClient?.disconnect()

        // Flush the AVSampleBufferVideoRenderer (Path A)
        stereoRenderer.flush()
        stereoRenderer.stopRequestingMediaData()

        isConnected = false
        isInitialized = false
        isRendererReady = false
        lastPTS = nil
        hasLoggedNoTarget = false
        lastEnqueuePixelBuffer = nil
        framesEnqueuedCount = 0
        videoPlayerFrameCounter = 0
    }

    private func startSignaling() throws {
        logger.info("📡 Creating SignalingClient for: \(self.signalingServerURL.absoluteString)")
        signalingClient = SignalingClient(serverURL: self.signalingServerURL)
        signalingClient?.delegate = self

        logger.info("📡 Connecting to signaling server as 'receiver'...")
        try signalingClient?.connect(as: "receiver")
        logger.info("📡 SignalingClient connection initiated")
    }

    private func setupStereoRenderer() {
        // Configure the renderer for stereo playback
        // The renderer is consumed by VideoPlayerComponent in RealityKit

        // Request media data to activate the renderer
        stereoRenderer.requestMediaDataWhenReady(on: .main) { [weak self] in
            guard let self = self else { return }

            // This callback indicates renderer is ready for data
            if !self.isRendererReady {
                self.isRendererReady = true
                self.logger.info("✅ AVSampleBufferVideoRenderer is now ready for tagged stereo frames")

                // Replay last buffered frame if available
                if let bufferedPB = self.lastEnqueuePixelBuffer {
                    self.logger.info("🔄 Replaying buffered frame now that renderer is ready")
                    self.enqueueSingleStreamImmediate(
                        buffer: bufferedPB,
                        pts: self.lastEnqueuePTS,
                        duration: self.lastEnqueueDuration
                    )
                }
            }
        }

        // Observe flush notifications to resume decoding when needed
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            for await _ in NotificationCenter.default.notifications(
                named: AVSampleBufferVideoRenderer.requiresFlushToResumeDecodingDidChangeNotification,
                object: self.stereoRenderer
            ) {
                self.logger.info("🔄 Flushing stereo renderer to resume decoding")
                self.stereoRenderer.flush()
            }
        }

        // WORKAROUND: Listen for decoded HEVC frames directly from decoder
        NotificationCenter.default.addObserver(
            forName: .hevcFrameDecoded,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract userInfo before Task to avoid capture issues
            guard let userInfo = notification.userInfo,
                  let pixelBuffer = userInfo["pixelBuffer"],
                  let frame = userInfo["frame"] as? LKRTCVideoFrame else {
                return
            }

            // CVPixelBuffer is a CoreFoundation type, cast directly
            let pb = pixelBuffer as! CVPixelBuffer

            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Only log occasionally to avoid spam
                if self.framesReceived % 120 == 0 {
                    self.logger.info("📢 Received HEVC frame via notification workaround")
                }
                self.processFrame(pb, from: frame)
            }
        }

        logger.info("⏳ AVSampleBufferVideoRenderer configured for stereo playback...")
    }

    // MARK: - Path A: Single-stream CMSampleBuffer wrapping

    private func enqueueSingleStream(buffer pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        // Check if renderer is ready
        guard isRendererReady else {
            // Buffer the frame until renderer is ready
            self.lastEnqueuePixelBuffer = pixelBuffer
            self.lastEnqueuePTS = pts
            self.lastEnqueueDuration = duration

            if !hasLoggedNoTarget {
                logger.info("⏳ Renderer not ready yet, buffering frame...")
                hasLoggedNoTarget = true
            }
            return
        }

        // Renderer is ready, enqueue immediately
        enqueueSingleStreamImmediate(buffer: pixelBuffer, pts: pts, duration: duration)
    }

    private func enqueueSingleStreamImmediate(buffer pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        // Check renderer status
        let rendererStatus = stereoRenderer.status
        if rendererStatus == .failed {
            logger.warning("⚠️ Renderer status failed, attempting recovery")
            stereoRenderer.flush()
            stereoRenderer.stopRequestingMediaData()
            stereoRenderer.requestMediaDataWhenReady(on: .main) { /* keep ready */ }
            return
        }

        // Log renderer readiness on first frame
        if self.framesEnqueuedCount == 0 {
            logger.info("📊 Renderer status: \(rendererStatus.rawValue), isReadyForMoreMediaData: \(self.stereoRenderer.isReadyForMoreMediaData)")
        }

        // Create format description
        var formatDesc: CMVideoFormatDescription?
        let statusFD = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDesc
        )
        guard statusFD == noErr, let formatDesc else {
            logger.error("❌ CMVideoFormatDescriptionCreateForImageBuffer failed: \(statusFD)")
            return
        }

        // Add stereo hint to format description (Hero Eye = Left)
        // This hints to RealityKit VideoMaterial that this is stereo content
        CMSetAttachment(
            formatDesc,
            key: kCMFormatDescriptionExtension_HeroEye as CFString,
            value: kCMFormatDescriptionHeroEye_Left as CFTypeRef,
            attachmentMode: kCMAttachmentMode_ShouldPropagate
        )

        let finalFormatDesc = formatDesc

        // Log pixel buffer format on first frame
        if self.framesEnqueuedCount == 0 {
            let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            logger.info("📊 PixelBuffer format: \(pixelFormat), size: \(width)x\(height)")
        }

        var timing = CMSampleTimingInfo(
            duration: duration == .invalid ? CMTime(value: 1, timescale: 60) : duration,
            presentationTimeStamp: pts,
            decodeTimeStamp: .invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let statusSB = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: finalFormatDesc,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard statusSB == noErr, let sb = sampleBuffer else {
            logger.error("❌ CMSampleBufferCreateReadyWithImageBuffer failed: \(statusSB)")
            return
        }

        // Display immediately to avoid timebase ambiguity
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) {
            let arr = attachments as NSArray
            if let dict = arr.firstObject as? NSMutableDictionary {
                dict[kCMSampleAttachmentKey_DisplayImmediately] = true
                dict[kCMSampleAttachmentKey_DoNotDisplay] = false
            }
        }

        // Log detailed info for first few frames
        if self.framesEnqueuedCount < 3 {
            logger.info("🎬 Enqueueing frame #\(self.framesEnqueuedCount + 1)")
            logger.info("   PTS: \(pts.seconds)s, duration: \(duration.seconds)s")
            logger.info("   SampleBuffer valid: \(CMSampleBufferIsValid(sb))")
            logger.info("   Hero Eye attachment: Left")
        }

        stereoRenderer.enqueue(sb)
        self.framesEnqueuedCount += 1

        if self.framesEnqueuedCount == 1 {
            logger.info("✅ First frame enqueued to stereoRenderer")
        } else if self.framesEnqueuedCount % 60 == 0 {
            logger.debug("📊 Enqueued \(self.framesEnqueuedCount) frames total")
        }
    }

    // MARK: - Stereo Tagged Stream (ConvertingModel path)

    private func enqueueStereoTaggedStream(buffer pixelBuffer: CVPixelBuffer, pts: CMTime, duration: CMTime) {
        // Update frame size immediately from source
        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        let perEyeWidth = srcWidth / 2  // SBS, so per-eye is half width

        if currentFrameSize.width != CGFloat(perEyeWidth) || currentFrameSize.height != CGFloat(srcHeight) {
            let oldSize = currentFrameSize
            currentFrameSize = CGSize(width: perEyeWidth, height: srcHeight)
            logger.info("📐 VideoPlayer frame size: \(Int(oldSize.width))×\(Int(oldSize.height)) → \(perEyeWidth)×\(srcHeight)")
        }

        // Frame counter for logging
        videoPlayerFrameCounter += 1

        // Log processing (reduced frequency for CPU optimization)
        if videoPlayerFrameCounter <= 10 || videoPlayerFrameCounter % 120 == 0 {
            logger.info("🎬 Processing VideoPlayer frame #\(self.videoPlayerFrameCounter): \(srcWidth)×\(srcHeight)")
        }

        Task { [weak self] in
            guard let self = self else { return }

            do {
                // Use ConvertingModel to split SBS into tagged stereo sample
                guard let stereoSample = try await self.convertingModel?.process(pixelBuffer, pts: pts, duration: duration) else {
                    if self.videoPlayerFrameCounter <= 10 {
                        self.logger.error("❌ Failed to convert SBS to stereo tagged sample")
                    }
                    return
                }

                await self.enqueueReadyStereoSample(stereoSample)
            } catch {
                if self.videoPlayerFrameCounter <= 10 {
                    self.logger.error("❌ ConvertingModel error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func enqueueReadyStereoSample(_ sample: CMSampleBuffer) async {
        // Check if renderer is ready
        guard isRendererReady else {
            if videoPlayerFrameCounter <= 5 {
                logger.warning("⏳ [VIDEOPLAY DEBUG] Renderer not ready (frame #\(self.videoPlayerFrameCounter)), skipping...")
                logger.warning("   Renderer status: \(self.stereoRenderer.status.rawValue)")
                logger.warning("   Ready for data: \(self.stereoRenderer.isReadyForMoreMediaData)")
            }
            return
        }

        // Check renderer status
        let rendererStatus = stereoRenderer.status
        if rendererStatus == .failed {
            logger.warning("⚠️ Renderer status failed, attempting recovery")
            stereoRenderer.flush()
            stereoRenderer.stopRequestingMediaData()
            stereoRenderer.requestMediaDataWhenReady(on: .main) { /* keep ready */ }
            return
        }

        // Log on first frame
        if self.framesEnqueuedCount == 0 {
            logger.info("📊 Renderer status: \(rendererStatus.rawValue), isReadyForMoreMediaData: \(self.stereoRenderer.isReadyForMoreMediaData)")
            logger.info("✅ First stereo tagged frame from ConvertingModel")

            // Debug stereo sample buffer format (first frame only)
            if let formatDesc = CMSampleBufferGetFormatDescription(sample) {
                let mediaType = CMFormatDescriptionGetMediaType(formatDesc)
                let mediaSubType = CMFormatDescriptionGetMediaSubType(formatDesc)
                logger.info("🔍 [PINK DEBUG] Format: mediaType=\(mediaType), subType=\(mediaSubType)")

                // Check dimensions
                let dims = CMVideoFormatDescriptionGetDimensions(formatDesc)
                logger.info("🔍 [PINK DEBUG] Format dimensions: \(dims.width)×\(dims.height)")
            }

            // Check for hero eye attachment on SAMPLE BUFFER (not format description)
            // For tagged buffer groups, the attachment is on the sample buffer itself
            if let heroEye = CMGetAttachment(sample as CMAttachmentBearer, key: kCMFormatDescriptionExtension_HeroEye as CFString, attachmentModeOut: nil) {
                logger.info("✅ [PINK DEBUG] HeroEye attachment on sample buffer: \(heroEye as! NSObject)")
            } else {
                logger.warning("⚠️ [PINK DEBUG] No HeroEye attachment found on sample buffer!")
            }

            // Check sample buffer validity
            let isValid = CMSampleBufferIsValid(sample)
            let dataReady = CMSampleBufferDataIsReady(sample)
            logger.info("🔍 [PINK DEBUG] Sample valid: \(isValid), dataReady: \(dataReady)")
        }

        stereoRenderer.enqueue(sample)
        self.framesEnqueuedCount += 1

        if self.framesEnqueuedCount == 1 {
            logger.info("✅ First stereo tagged sample enqueued to stereoRenderer")
        } else if self.framesEnqueuedCount % 60 == 0 {
            logger.debug("📊 Enqueued \(self.framesEnqueuedCount) stereo frames total")
        }

        // Monitor for pink screen - check if error occurs after enqueue
        if self.framesEnqueuedCount <= 5 {
            // Check renderer status right after enqueue
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                let statusAfter = self.stereoRenderer.status
                if statusAfter == .failed {
                    self.logger.error("❌ [PINK DEBUG] Renderer FAILED after enqueue frame #\(self.framesEnqueuedCount)")
                }
            }
        }
    }

    // MARK: - Path B: Stereo Metal update (legacy, deprecated)

    private func feedStereoMetal(with pixelBuffer: CVPixelBuffer) {
        // Update frame size (SBS source, so per-eye is half width)
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        // For SBS, each eye is half the width
        let perEyeWidth = width / 2

        if currentFrameSize.width != CGFloat(perEyeWidth) || currentFrameSize.height != CGFloat(height) {
            let oldSize = currentFrameSize
            currentFrameSize = CGSize(width: perEyeWidth, height: height)
            logger.info("📐 Metal frame size: \(Int(oldSize.width))×\(Int(oldSize.height)) → \(perEyeWidth)×\(height)")
        }

        // Ensure BGRA for StereoVideoRenderer
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        if format == kCVPixelFormatType_32BGRA {
            stereoMetalRenderer.updateFrame(pixelBuffer)
            return
        }

        // Convert YUV (e.g., 420f/NV12) to BGRA via CIContext
        guard let bgraBuffer = makeBGRA(from: pixelBuffer) else {
            logger.error("❌ Failed to convert to BGRA")
            return
        }

        stereoMetalRenderer.updateFrame(bgraBuffer)
    }

    private func makeBGRA(from pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary
        ]

        var outPB: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &outPB) == kCVReturnSuccess,
              let dst = outPB else {
            return nil
        }

        let srcImage = CIImage(cvPixelBuffer: pixelBuffer)
        ciContext.render(srcImage, to: dst)
        return dst
    }

    nonisolated private func handleOffer(_ offer: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.logger.info("📥 SIGNAL_RX:offer")

            let sessionDescription = LKRTCSessionDescription(type: .offer, sdp: offer)

            self.peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    self.logger.error("❌ SDP:setRemoteDescription(offer) failed: \(error.localizedDescription)")
                    return
                }

                self.logger.info("✅ SDP:setRemoteDescription(offer) success")

                Task { @MainActor in
                    self.remoteDescriptionSet = true
                    self.flushPendingRemoteCandidates()
                    await self.createAnswer()
                }
            }
        }
    }

    private func flushPendingRemoteCandidates() {
        guard remoteDescriptionSet else {
            logger.warning("⚠️ Cannot flush candidates: remote description not set")
            return
        }

        logger.info("🔄 Flushing \(self.pendingRemoteCandidates.count) queued remote candidates")

        for candidate in self.pendingRemoteCandidates {
            peerConnection?.add(candidate) { [weak self] error in
                if let error = error {
                    Task { @MainActor in
                        self?.logger.error("❌ Failed to add queued ICE candidate: \(error.localizedDescription)")
                    }
                } else {
                    Task { @MainActor in
                        self?.logger.debug("✅ Queued ICE candidate added")
                    }
                }
            }
        }

        self.pendingRemoteCandidates.removeAll()
        logger.info("✅ All queued candidates processed")
    }

    private func createAnswer() async {
        logger.info("📝 SDP:createAnswer")

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: [
                kLKRTCMediaConstraintsOfferToReceiveVideo: kLKRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: nil
        )

        peerConnection?.answer(for: constraints) { [weak self] sdp, error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("❌ SDP:createAnswer failed: \(error.localizedDescription)")
                return
            }

            guard let sdp = sdp else {
                self.logger.error("❌ SDP:createAnswer returned nil")
                return
            }

            Task { @MainActor in
                self.logger.info("📄 SDP Answer created")

                self.peerConnection?.setLocalDescription(sdp) { [weak self] error in
                    guard let self = self else { return }

                    if let error = error {
                        self.logger.error("❌ SDP:setLocalDescription(answer) failed: \(error.localizedDescription)")
                        return
                    }

                    self.logger.info("✅ SDP:setLocalDescription(answer) success")

                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.signalingClient?.send(answer: sdp.sdp)
                        self.logger.info("📤 SIGNAL_TX:answer")
                    }
                }
            }
        }
    }
}

extension WebRTCReceiver: LKRTCPeerConnectionDelegate {
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {
        Task { @MainActor in
            self.logger.info("🔄 SIGNALING_STATE:\(stateChanged.rawValue)")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {
        print("📦 Stream received with \(stream.videoTracks.count) video tracks")

        if let videoTrack = stream.videoTracks.first {
            Task { @MainActor in
                self.logger.info("➕ Media stream added: track enabled=\(videoTrack.isEnabled), state=\(videoTrack.readyState.rawValue)")
                self.remoteVideoTrack = videoTrack
                videoTrack.add(self)
            }
        } else {
            Task { @MainActor in
                self.logger.warning("⚠️ Media stream added but no video track found")
            }
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {
        Task { @MainActor in
            self.logger.info("➖ Media stream removed")
        }
    }

    nonisolated public func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {
        Task { @MainActor in
            self.logger.info("🔄 Should negotiate")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        Task { @MainActor in
            self.logger.info("🧊 ICE_STATE:\(newState.rawValue)")

            self.isConnected = (newState == .connected || newState == .completed)

            if newState == .connected || newState == .completed {
                self.logger.info("🎉 WebRTC connection established!")
            } else if newState == .disconnected {
                self.logger.warning("⚠️ ICE_STATE:disconnected - Media connection lost!")
                print("⚠️ Possible causes: Network change, firewall, or NAT issue")
            } else if newState == .failed {
                self.logger.error("❌ ICE_STATE:failed - Cannot establish media connection")
                print("❌ Check: Both devices on same network? Firewall blocking UDP?")
            }
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {
        Task { @MainActor in
            self.logger.info("🧊 GATHERING_STATE:\(newState.rawValue)")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.logger.info("🧊 ICE:local-candidate generated")
            self.signalingClient?.send(iceCandidate: candidate)
            self.logger.info("📤 SIGNAL_TX:local-candidate")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {
        Task { @MainActor in
            self.logger.info("🧊 Removed ICE candidates: \(candidates.count)")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {
        Task { @MainActor in
            self.logger.info("📡 Data channel opened")
        }
    }
}

extension WebRTCReceiver: LKRTCVideoRenderer {
    nonisolated public func setSize(_ size: CGSize) {
        print("📐 Video size set: \(size)")
    }

    nonisolated public func renderFrame(_ frame: LKRTCVideoFrame?) {
        guard let frame = frame else {
            return
        }

        // Get pixel buffer (either directly or via conversion)
        let pixelBuffer: CVPixelBuffer?

        if let cvBuffer = frame.buffer as? LKRTCCVPixelBuffer {
            // Fast path: already CVPixelBuffer
            pixelBuffer = cvBuffer.pixelBuffer
        } else if let i420Buffer = frame.buffer as? LKRTCI420Buffer {
            // Convert I420 to CVPixelBuffer

            Task { @MainActor [weak self] in
                guard let self = self, let converter = self.i420Converter else { return }

                if let converted = await converter.convert(i420Buffer) {
                    self.processFrame(converted, from: frame)
                }
            }
            return
        } else {
            return
        }

        guard let pb = pixelBuffer else { return }

        Task { @MainActor in
            self.processFrame(pb, from: frame)
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer, from frame: LKRTCVideoFrame) {
        // Update current frame for debugging
        self.currentFrame = pixelBuffer
        self.framesReceived += 1

        // Update stats
        self.stats = ReceiverStats(framesReceived: self.framesReceived)

        // Compute timing
        let timeStampSeconds = Double(frame.timeStampNs) / 1_000_000_000.0
        let pts = CMTime(seconds: timeStampSeconds, preferredTimescale: 1_000_000_000)
        let duration: CMTime
        if let last = self.lastPTS {
            duration = CMTimeSubtract(pts, last)
        } else {
            duration = CMTime(value: 1, timescale: 60)
        }
        self.lastPTS = pts

        // Render to selected path only (no simultaneous multi-path rendering)
        switch currentRenderPath {
        case .videoPlayer:
            // PATH A: Use ConvertingModel to split SBS and create tagged stereo CMSampleBuffer
            // This properly splits SBS video into left/right eye buffers with stereo tags
            enqueueStereoTaggedStream(buffer: pixelBuffer, pts: pts, duration: duration)

        case .metal:
            // PATH B: Update Stereo Metal renderer with BGRA frames
            // This is the working path for RealityKit stereo display
            self.feedStereoMetal(with: pixelBuffer)
        }

        // Log frames received every 60 frames
        if self.framesReceived % 60 == 0 {
            let pathName = currentRenderPath == .videoPlayer ? "VideoPlayerComponent" : "StereoVideoRenderer"
            self.logger.info("📊 Received \(self.framesReceived) frames, feeding to \(pathName)")
        }
    }
}

extension WebRTCReceiver: SignalingDelegate {
    nonisolated func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String) {
        handleOffer(sdp)
    }

    nonisolated func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String) {
        Task { @MainActor in
            self.logger.warning("⚠️ Received unexpected answer (Vision Pro is receiver)")
        }
    }

    nonisolated func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.logger.debug("📥 SIGNAL_RX:remote-candidate")

            let iceCandidate = LKRTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)

            if !self.remoteDescriptionSet {
                self.pendingRemoteCandidates.append(iceCandidate)
                self.logger.info("📥 SIGNAL_RX:remote-candidate queued (count: \(self.pendingRemoteCandidates.count))")
                return
            }

            self.peerConnection?.add(iceCandidate) { [weak self] error in
                if let error = error {
                    Task { @MainActor in
                        self?.logger.error("❌ Failed to add remote ICE candidate: \(error.localizedDescription)")
                    }
                } else {
                    Task { @MainActor in
                        self?.logger.debug("✅ SIGNAL_RX:remote-candidate added")
                    }
                }
            }
        }
    }

    nonisolated func signalingClient(_ client: SignalingClient, didChangeState state: SignalingState) {
        Task { @MainActor in
            self.logger.info("🔄 Signaling state: \(String(describing: state))")
        }
    }
}

public struct ReceiverStats {
    public let framesReceived: Int
    public let packetsReceived: Int
    public let packetsLost: Int

    public init(framesReceived: Int = 0, packetsReceived: Int = 0, packetsLost: Int = 0) {
        self.framesReceived = framesReceived
        self.packetsReceived = packetsReceived
        self.packetsLost = packetsLost
    }

    public var packetLossRatio: Double {
        guard packetsReceived > 0 else { return 0.0 }
        return Double(packetsLost) / Double(packetsReceived + packetsLost)
    }
}

enum ReceiverError: Error {
    case initializationFailed(String)
}
