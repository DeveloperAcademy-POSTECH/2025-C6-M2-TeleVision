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

    // Path A (single-stream) renderer for RealityKit VideoMaterial with stereo tagging
    public let stereoRenderer = AVSampleBufferVideoRenderer()

    // Path B (stereo Metal) renderer - Legacy RealityKit approach (deprecated, use Path A instead)
    public let stereoMetalRenderer = StereoVideoRenderer()

    // Optional: legacy converting model for tagged stereo CMSampleBuffer (kept for experimentation)
    private var convertingModel: ConvertingModel?

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
        let decoderFactory = LKRTCDefaultVideoDecoderFactory()

        peerConnectionFactory = LKRTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )

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
        // If renderer failed, try recovery
        if stereoRenderer.status == .failed {
            logger.warning("⚠️ Renderer status failed, attempting recovery")
            stereoRenderer.flush()
            stereoRenderer.stopRequestingMediaData()
            stereoRenderer.requestMediaDataWhenReady(on: .main) { /* keep ready */ }
            return
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

        stereoRenderer.enqueue(sb)
        self.framesEnqueuedCount += 1

        if self.framesEnqueuedCount == 1 {
            logger.info("✅ First frame enqueued to renderer")
        } else if self.framesEnqueuedCount % 60 == 0 {
            logger.debug("📊 Enqueued \(self.framesEnqueuedCount) frames total")
        }
    }

    // MARK: - Path B: Stereo Metal update (legacy, deprecated)

    private func feedStereoMetal(with pixelBuffer: CVPixelBuffer) {
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
        if let videoTrack = stream.videoTracks.first {
            Task { @MainActor in
                self.logger.info("➕ Media stream added with video track")
                self.remoteVideoTrack = videoTrack
                videoTrack.add(self)
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
                self.logger.warning("⚠️ ICE_STATE:disconnected")
            } else if newState == .failed {
                self.logger.error("❌ ICE_STATE:failed")
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
            print("⚠️ renderFrame called with nil frame")
            return
        }

        // Prefer CVPixelBuffer-backed frames to avoid CPU conversions
        guard let cvBuffer = frame.buffer as? LKRTCCVPixelBuffer else {
            print("⚠️ Non-CVPixelBuffer frame received, dropping to avoid CPU conversion: \(type(of: frame.buffer))")
            return
        }

        let pixelBuffer = cvBuffer.pixelBuffer
        print("🎬 Frame received! Size: \(CVPixelBufferGetWidth(pixelBuffer))×\(CVPixelBufferGetHeight(pixelBuffer))")

        Task { @MainActor in
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

            // PATH A: Use ConvertingModel to create tagged stereo CMSampleBuffer
            do {
                if let convertingModel = self.convertingModel {
                    // 🔍 DIAGNOSTIC: Log renderer status every frame (temporary for debugging)
                    if self.framesReceived <= 10 || self.framesReceived % 10 == 0 {
                        self.logger.info("🔍 [DIAGNOSTIC] Frame #\(self.framesReceived): Renderer ready=\(self.stereoRenderer.isReadyForMoreMediaData) status=\(self.stereoRenderer.status.rawValue)")
                    }

                    if self.stereoRenderer.isReadyForMoreMediaData,
                       let stereoSampleBuffer = try await convertingModel.process(pixelBuffer, pts: pts, duration: duration) {
                        self.stereoRenderer.enqueue(stereoSampleBuffer)
                        self.logger.info("🔍 [DIAGNOSTIC] ✅ Enqueued frame #\(self.framesReceived) to renderer")

                        // Log every 60 frames
                        if self.framesReceived % 60 == 0 {
                            self.logger.info("📊 Enqueued \(self.framesReceived) tagged stereo frames to renderer")
                        }
                    } else {
                        if !self.stereoRenderer.isReadyForMoreMediaData {
                            self.logger.warning("🔍 [DIAGNOSTIC] ⚠️ Frame #\(self.framesReceived): Renderer NOT ready (ready=\(self.stereoRenderer.isReadyForMoreMediaData))")
                        } else {
                            self.logger.error("🔍 [DIAGNOSTIC] ❌ Frame #\(self.framesReceived): Failed to process stereo sample buffer")
                        }
                    }
                }
            } catch {
                self.logger.error("❌ Failed to process stereo frame: \(error.localizedDescription)")
            }

            // PATH B: Update Stereo Metal renderer with BGRA frames (backup)
            // self.feedStereoMetal(with: pixelBuffer)

            // Optional: keep legacy converting model working behind a flag if needed
            /*
            do {
                if let convertingModel = self.convertingModel,
                   let stereoSampleBuffer = try await convertingModel.process(pixelBuffer, pts: pts, duration: duration) {
                    self.stereoRenderer.enqueue(stereoSampleBuffer)
                    self.logger.debug("✅ (Legacy) Stereo tagged frame enqueued")
                }
            } catch {
                self.logger.error("❌ (Legacy) Failed to process stereo frame: \(error.localizedDescription)")
            }
            */
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
