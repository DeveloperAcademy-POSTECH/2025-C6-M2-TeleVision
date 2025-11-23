//
//  WebRTCReceiver.swift
//  Hippo
//
//  WebRTC receiver for Vision Pro
//  Mac (Sender) → Vision Pro (Receiver)
//

import Foundation
@preconcurrency import CoreVideo
@preconcurrency import CoreMedia
@preconcurrency import AVFoundation
import os.log
@preconcurrency import LiveKitWebRTC
import Combine
import CoreImage

// MARK: - Sendable Wrapper

/// Thread-safe wrapper for CVPixelBuffer
fileprivate struct SendablePixelBuffer: @unchecked Sendable {
    nonisolated(unsafe) let pixelBuffer: CVPixelBuffer

    nonisolated init(_ pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
    }
}

// MARK: - WebRTC Receiver

@MainActor
public final class WebRTCReceiver: NSObject, ObservableObject {

    // MARK: - Constants

    private enum LoggingInterval {
        static let standardFrames = 60
        static let frequentFrames = 120
        static let initialFrames = 10
        static let debugFrames = 5
        static let detailedDebugFrames = 3

        // UInt64 versions for videoPlayerFrameCounter
        static let initialFramesU64: UInt64 = 10
        static let frequentFramesU64: UInt64 = 120
    }

    // MARK: - Logging State

    private struct LoggingState {
        var hasLoggedRendererReady: Bool = false
        var hasLoggedNoTarget: Bool = false
        var framesEnqueuedCount: Int = 0
    }

    // MARK: - Published Properties

    @Published public var isConnected: Bool = false
    @Published public var currentFrame: CVPixelBuffer?
    @Published public var stats: ReceiverStats = ReceiverStats()
    @Published public var currentFrameSize: CGSize = .zero  // Track current per-eye frame size

    // MARK: - Pipeline Components

    /// Rendering components (Metal, VideoPlayer, ConvertingModel) are now managed by EndoscopeRenderPipeline.
    /// WebRTCReceiver only manages WebRTC-specific resources (I420 converter, signaling, peer connection).
    /// This separation follows Dependency Injection pattern for better testability and resource management.

    // I420 buffer converter for non-CVPixelBuffer frames (WebRTC-specific)
    private var i420Converter: I420BufferConverter?

    // MARK: - Backward Compatibility

    /// Dummy renderer for fallback (used before pipeline is ready or in non-stereo modes)
    /// Created lazily and reused to avoid repeated instantiation
    private lazy var dummyRenderer: AVSampleBufferVideoRenderer = {
        let renderer = AVSampleBufferVideoRenderer()
        logger.info("📦 Dummy AVSampleBufferVideoRenderer created (fallback)")
        return renderer
    }()

    /// Backward compatibility: Expose videoRenderer for VideoPlayerComponent
    /// Returns actual pipeline renderer in stereo3D mode, dummy renderer otherwise
    public var stereoRenderer: AVSampleBufferVideoRenderer {
        if let renderer = renderPipeline.getVideoRenderer()?.videoRenderer {
            return renderer
        } else {
            logger.warning("⚠️ stereoRenderer accessed before pipeline ready or in non-stereo mode (\(self.currentViewMode.rawValue))")
            return dummyRenderer
        }
    }

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
    private var isRendererSetup: Bool = false  // Prevent duplicate setupStereoRenderer() calls
    private nonisolated(unsafe) static var globalInitCount: Int = 0
    nonisolated private static let initLock = NSLock()

    // MARK: Log throttling
    private var loggingState = LoggingState()

    // MARK: - Rendering Pipeline (DI)

    /// Rendering pipeline - injected via DI for testability
    /// Manages all mode-specific rendering logic and resources
    public let renderPipeline: EndoscopeRenderPipeline

    /// Current view mode - synced with pipeline
    @Published public var currentViewMode: EndoscopeViewMode = .rawStream

    /// Pipeline configuration based on current mode
    private var pipelineConfig: EndoscopePipelineConfig {
        EndoscopePipelineConfig(mode: currentViewMode)
    }

    // MARK: CIContext for YUV -> BGRA conversion (for Metal renderer path)
    private lazy var ciContext: CIContext = {
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,
            .cacheIntermediates: true
        ]
        return CIContext(options: options)
    }()

    /// Initialize WebRTCReceiver with dependency injection
    /// - Parameters:
    ///   - signalingServerURL: WebSocket URL for signaling server
    ///   - renderPipeline: Rendering pipeline (must be created in @MainActor context)
    /// - Note: renderPipeline must be created by caller in @MainActor context to avoid actor isolation issues
    public init(
        signalingServerURL: URL = URL(string: "ws://127.0.0.1:8080")!,
        renderPipeline: EndoscopeRenderPipeline
    ) {
        self.signalingServerURL = signalingServerURL
        self.renderPipeline = renderPipeline
        super.init()

        // Setup pipeline callbacks for data flow: Pipeline → Receiver
        setupPipelineCallbacks()

        // CRITICAL: Do NOT configure pipeline here!
        // Pipeline will be configured externally based on desired initial mode
        // This prevents hardcoding .rawStream as the only initial mode
        logger.info("WebRTCReceiver initialized (pipeline configuration deferred to caller)")
    }

    /// Performs global WebRTC initialization in a thread-safe manner (nonisolated for lock usage)
    nonisolated private func performGlobalInitIfNeeded() -> Int {
        Self.initLock.lock()
        defer { Self.initLock.unlock() }

        if Self.globalInitCount == 0 {
            LKRTCInitializeSSL()
            LKRTCSetupInternalTracer()
            Self.globalInitCount += 1
        }
        return Self.globalInitCount
    }

    // MARK: - Pipeline Callbacks Setup

    /// Setup callbacks for Pipeline → Receiver communication
    private func setupPipelineCallbacks() {
        // Frame size changes from pipeline
        renderPipeline.onFrameSizeChanged = { [weak self] newSize in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentFrameSize = newSize
                self.logger.debug("📐 Frame size updated: \(Int(newSize.width))×\(Int(newSize.height))")
            }
        }

        // Mode changes from pipeline
        renderPipeline.onModeChanged = { [weak self] newMode in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentViewMode = newMode
                self.logger.info("🔄 Mode synced: \(newMode.rawValue)")
            }
        }

        // Error handling from pipeline
        renderPipeline.onError = { [weak self] error in
            guard let self = self else { return }
            Task { @MainActor in
                self.logger.error("❌ Pipeline error: \(error.localizedDescription)")
            }
        }

        logger.info("✅ Pipeline callbacks configured")
    }

    // MARK: - View Mode Management

    /// Set view mode and reconfigure pipeline accordingly
    /// - Parameter mode: Target view mode
    /// - Note: Delegates to renderPipeline for actual resource management
    public func setViewMode(_ mode: EndoscopeViewMode) {
        // Skip if already in this mode
        guard currentViewMode != mode else {
            logger.info("✓ Already in mode: \(mode.rawValue)")
            return
        }

        logger.info("🔄 Receiver: Requesting mode switch to \(mode.rawValue)")

        // Delegate to pipeline (will trigger onModeChanged callback)
        renderPipeline.configure(for: mode)

        // currentViewMode will be updated via callback
        logger.info("✅ Mode switch request complete")
    }

    /// Update the signaling server URL (requires restart)
    public func updateSignalingServer(url: URL) async throws {
        logger.info("WebRTCReceiver: Updating signaling server URL to: \(url.absoluteString)")

        // Stop current connection
        logger.info("   Stopping existing connection...")
        await stop()

        // Update URL
        signalingServerURL = url
        logger.info("   URL updated, starting WebRTC...")

        // Restart with new URL
        try await start()
        logger.info("   WebRTC started successfully")
    }

    public func start() async throws {
        guard !isInitialized else {
            logger.warning("WebRTC Receiver already started, skipping...")
            return
        }

        logger.info("WebRTC Receiver starting...")
        logger.info("Initial mode: \(self.currentViewMode.rawValue)")

        // Initialize I420 buffer converter (common for all modes)
        i420Converter = I420BufferConverter()
        logger.info("I420BufferConverter initialized")

        // Configure pipeline for current mode
        renderPipeline.configure(for: currentViewMode)

        // Configure AVSampleBufferVideoRenderer if needed (for VideoPlayer mode)
        if pipelineConfig.enableVideoPlayer {
            setupStereoRenderer()
        }

        // Thread-safe global initialization
        let initCount = performGlobalInitIfNeeded()
        if initCount == 1 {
            logger.info("WebRTC global initialization complete (count: \(initCount))")
        } else {
            logger.info("WebRTC already globally initialized (count: \(initCount)), reusing...")
        }

        let encoderFactory = LKRTCDefaultVideoEncoderFactory()
        // Use HEVC decoder factory for better compression
        let decoderFactory = HEVCVideoDecoderFactory()

        peerConnectionFactory = LKRTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        logger.info("Peer connection factory created with HEVC decoder support")

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
        logger.info("WebRTC Receiver initialized")
    }

    public func stop() async {
        guard isInitialized else {
            logger.warning("WebRTC Receiver not initialized, skipping stop...")
            return
        }

        logger.info("WebRTC Receiver stopping...")

        // 1. Stop timers immediately
        statsTimer?.invalidate()

        // 2. Cleanup pipeline FIRST (stops frame processing)
        renderPipeline.cleanup()

        // 3. Disconnect signaling (fast, non-blocking after our fix)
        signalingClient?.disconnect()

        // 4. Close peer connection in background with timeout
        if let pc = peerConnection {
            Task.detached {
                pc.close()
            }
        }

        // 5. Remove notification observers to prevent memory leaks
        NotificationCenter.default.removeObserver(self, name: .hevcFrameDecoded, object: nil)

        // 6. Release common resources
        i420Converter = nil
        peerConnection = nil
        remoteVideoTrack = nil
        signalingClient = nil

        // 7. Reset state
        isConnected = false
        isInitialized = false
        isRendererSetup = false
        lastPTS = nil
        loggingState = LoggingState()
        videoPlayerFrameCounter = 0
        pendingRemoteCandidates.removeAll()
        remoteDescriptionSet = false

        logger.info("✅ WebRTC Receiver stopped, all resources released")
    }

    private func startSignaling() throws {
        logger.info("Creating SignalingClient for: \(self.signalingServerURL.absoluteString)")
        signalingClient = SignalingClient(serverURL: self.signalingServerURL)
        signalingClient?.delegate = self

        logger.info("Connecting to signaling server as 'receiver'...")
        try signalingClient?.connect(as: "receiver")
        logger.info("SignalingClient connection initiated")
    }

    private func setupStereoRenderer() {
        // Prevent duplicate setup to avoid memory leaks from multiple observers
        guard !isRendererSetup else {
            logger.info("StereoRenderer already set up, skipping...")
            return
        }

        isRendererSetup = true

        // Note: Renderer initialization is now handled by StereoVideoPlayer
        // This method only sets up WebRTC-specific notifications

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
            let sendableBuffer = SendablePixelBuffer(pb)

            Task { @MainActor [weak self, sendableBuffer] in
                guard let self = self else { return }
                // Only log occasionally to avoid spam
                if self.framesReceived % LoggingInterval.frequentFrames == 0 {
                    self.logger.info("Received HEVC frame via notification workaround")
                }
                await self.processFrame(sendableBuffer.pixelBuffer, from: frame)
            }
        }

        logger.info("StereoVideoPlayer configured, listening for HEVC frames...")
    }

    // MARK: - Legacy Methods Removed (DI Refactoring)
    //
    // The following methods were removed as part of DI pattern refactoring:
    //
    // Removed Methods:
    //   - enqueueSingleStream(buffer:pts:duration:)
    //   - enqueueStereoTaggedStream(buffer:pts:duration:)
    //   - enqueueReadyStereoSample(_:)
    //   - feedStereoMetal(with:)
    //   - makeBGRA(from:)
    //
    // New Delegation Point:
    //   All frame processing is now delegated to EndoscopeRenderPipeline:
    //   → renderPipeline.processFrame(_:pts:duration:)
    //
    // Benefits:
    //   • Single source of truth for mode-specific frame routing
    //   • Pipeline handles all Stage 1/2/3 logic internally
    //   • WebRTCReceiver focuses solely on WebRTC connection management

    nonisolated private func handleOffer(_ offer: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.logger.info("SIGNAL_RX:offer")

            let sessionDescription = LKRTCSessionDescription(type: .offer, sdp: offer)

            do {
                try await self.peerConnection?.setRemoteDescription(sessionDescription)
                self.logger.info("SDP:setRemoteDescription(offer) success")

                self.remoteDescriptionSet = true
                self.flushPendingRemoteCandidates()
                await self.createAnswer()
            } catch {
                self.logger.error("SDP:setRemoteDescription(offer) failed: \(error.localizedDescription)")
            }
        }
    }

    private func flushPendingRemoteCandidates() {
        guard remoteDescriptionSet else {
            logger.warning("Cannot flush candidates: remote description not set")
            return
        }

        logger.info("Flushing \(self.pendingRemoteCandidates.count) queued remote candidates")

        let candidates = self.pendingRemoteCandidates
        self.pendingRemoteCandidates.removeAll()

        Task { [weak self, candidates] in
            guard let self = self else { return }
            for candidate in candidates {
                do {
                    try await self.peerConnection?.addIceCandidate(candidate)
                    await MainActor.run {
                        self.logger.debug("Queued ICE candidate added")
                    }
                } catch {
                    await MainActor.run {
                        self.logger.error("Failed to add queued ICE candidate: \(error.localizedDescription)")
                    }
                }
            }
            await MainActor.run {
                self.logger.info("All queued candidates processed")
            }
        }
    }

    private func createAnswer() async {
        logger.info("SDP:createAnswer")

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: [
                kLKRTCMediaConstraintsOfferToReceiveVideo: kLKRTCMediaConstraintsValueTrue
            ],
            optionalConstraints: nil
        )

        do {
            guard let peerConnection = peerConnection else { return }

            let sdp = try await peerConnection.answer(for: constraints)
            logger.info("SDP Answer created")

            try await peerConnection.setLocalDescription(sdp)
            logger.info("SDP:setLocalDescription(answer) success")

            signalingClient?.send(answer: sdp.sdp)
            logger.info("SIGNAL_TX:answer")
        } catch {
            logger.error("SDP answer/setLocalDescription failed: \(error.localizedDescription)")
        }
    }
}

extension WebRTCReceiver: LKRTCPeerConnectionDelegate {
    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange stateChanged: LKRTCSignalingState) {
        Task { @MainActor in
            self.logger.info("SIGNALING_STATE:\(stateChanged.rawValue)")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {
        print("Stream received with \(stream.videoTracks.count) video tracks")

        if let videoTrack = stream.videoTracks.first {
            Task { @MainActor in
                self.logger.info("Media stream added: track enabled=\(videoTrack.isEnabled), state=\(videoTrack.readyState.rawValue)")
                self.remoteVideoTrack = videoTrack
                videoTrack.add(self)

                // Setup notification observer for HEVC frames
                self.setupStereoRenderer()
            }
        } else {
            Task { @MainActor in
                self.logger.warning("Media stream added but no video track found")
            }
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {
        Task { @MainActor in
            self.logger.info("Media stream removed")
        }
    }

    nonisolated public func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {
        Task { @MainActor in
            self.logger.info("Should negotiate")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        Task { @MainActor in
            self.logger.info("ICE_STATE:\(newState.rawValue)")

            self.isConnected = (newState == .connected || newState == .completed)

            if newState == .connected || newState == .completed {
                self.logger.info("WebRTC connection established!")
            } else if newState == .disconnected {
                self.logger.warning("ICE_STATE:disconnected - Media connection lost!")
                print("Possible causes: Network change, firewall, or NAT issue")
            } else if newState == .failed {
                self.logger.error("ICE_STATE:failed - Cannot establish media connection")
                print("Check: Both devices on same network? Firewall blocking UDP?")
            }
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {
        Task { @MainActor in
            self.logger.info("GATHERING_STATE:\(newState.rawValue)")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.logger.info("ICE:local-candidate generated")
            self.signalingClient?.send(iceCandidate: candidate)
            self.logger.info("SIGNAL_TX:local-candidate")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {
        Task { @MainActor in
            self.logger.info("Removed ICE candidates: \(candidates.count)")
        }
    }

    nonisolated public func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {
        Task { @MainActor in
            self.logger.info("Data channel opened")
        }
    }
}

extension WebRTCReceiver: LKRTCVideoRenderer {
    nonisolated public func setSize(_ size: CGSize) {
        print("Video size set: \(size)")
    }

    nonisolated public func renderFrame(_ frame: LKRTCVideoFrame?) {
        Task { @MainActor in
            print("🎬 renderFrame called!")
        }

        guard let frame = frame else {
            Task { @MainActor in
                print("⚠️ renderFrame: frame is nil")
            }
            return
        }

        Task { @MainActor in
            print("✅ renderFrame: Got frame \(frame.width)x\(frame.height)")
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
                    await self.processFrame(converted, from: frame)
                }
            }
            return
        } else {
            return
        }

        guard let pb = pixelBuffer else { return }
        let sendableBuffer = SendablePixelBuffer(pb)

        // Process frame using structured concurrency
        // StereoVideoPlayerHelper's serial queue ensures thread-safe VTPixelTransferSession access
        Task { [weak self, sendableBuffer] in
            guard let self = self else { return }
            await self.processFrame(sendableBuffer.pixelBuffer, from: frame)
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer, from frame: LKRTCVideoFrame) async {
        // Update stats and timing on main actor
        await MainActor.run {
            self.currentFrame = pixelBuffer
            self.framesReceived += 1
            self.stats = ReceiverStats(framesReceived: self.framesReceived)
        }

        // Compute timing
        let timeStampSeconds = Double(frame.timeStampNs) / 1_000_000_000.0
        let pts = CMTime(seconds: timeStampSeconds, preferredTimescale: 1_000_000_000)

        let duration: CMTime
        let lastPTS = await MainActor.run { self.lastPTS }
        if let last = lastPTS {
            duration = CMTimeSubtract(pts, last)
        } else {
            duration = CMTime(value: 1, timescale: 60)
        }
        await MainActor.run { self.lastPTS = pts }

        // Delegate frame processing to pipeline (runs on background)
        // Pipeline will route to appropriate stage based on current mode
        await renderPipeline.processFrame(pixelBuffer, pts: pts, duration: duration)

        // Log frames received periodically
        let framesReceived = await MainActor.run { self.framesReceived }
        let currentMode = await MainActor.run { self.currentViewMode }
        if framesReceived % LoggingInterval.standardFrames == 0 {
            logger.info("Received \(framesReceived) frames, mode: \(currentMode.rawValue)")
        }
    }
}

extension WebRTCReceiver: SignalingDelegate {
    nonisolated func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String) {
        handleOffer(sdp)
    }

    nonisolated func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String) {
        Task { @MainActor in
            self.logger.warning("Received unexpected answer (Vision Pro is receiver)")
        }
    }

    nonisolated func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            self.logger.debug("SIGNAL_RX:remote-candidate")

            let iceCandidate = LKRTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)

            if !self.remoteDescriptionSet {
                self.pendingRemoteCandidates.append(iceCandidate)
                self.logger.info("SIGNAL_RX:remote-candidate queued (count: \(self.pendingRemoteCandidates.count))")
                return
            }

            do {
                try await self.peerConnection?.addIceCandidate(iceCandidate)
                self.logger.debug("SIGNAL_RX:remote-candidate added")
            } catch {
                self.logger.error("Failed to add remote ICE candidate: \(error.localizedDescription)")
            }
        }
    }

    nonisolated func signalingClient(_ client: SignalingClient, didChangeState state: SignalingState) {
        Task { @MainActor in
            self.logger.info("Signaling state: \(String(describing: state))")
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

// MARK: - LKRTCPeerConnection Async/Await Extensions

extension LKRTCPeerConnection {
    /// Async wrapper for setRemoteDescription
    func setRemoteDescription(_ sessionDescription: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setRemoteDescription(sessionDescription) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Async wrapper for setLocalDescription
    func setLocalDescription(_ sessionDescription: LKRTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.setLocalDescription(sessionDescription) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// Async wrapper for answer(for:)
    func answer(for constraints: LKRTCMediaConstraints) async throws -> LKRTCSessionDescription {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<LKRTCSessionDescription, Error>) in
            self.answer(for: constraints) { sdp, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let sdp = sdp {
                    continuation.resume(returning: sdp)
                } else {
                    continuation.resume(throwing: NSError(domain: "WebRTCReceiver", code: -1, userInfo: [NSLocalizedDescriptionKey: "SDP answer is nil"]))
                }
            }
        }
    }

    /// Async wrapper for add(_:) ICE candidate
    func addIceCandidate(_ candidate: LKRTCIceCandidate) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.add(candidate) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
