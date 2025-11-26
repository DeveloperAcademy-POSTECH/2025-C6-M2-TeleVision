//
//  WebRTCManager.swift
//  Hippo
//
//  WebRTC manager for real-time video streaming
//  Enhanced with P0.1 (resolution downsample control) and P0.3 (ICE restart)
//

import Foundation
import CoreVideo
import CoreMedia
import os.log
import LiveKitWebRTC

// MARK: - WebRTC Manager

public final class WebRTCManager: NSObject, IVideoTransport {

    // MARK: - Constants

    private enum ConnectionConstants {
        static let disconnectionGracePeriod: TimeInterval = 10.0
        // OPTIMIZED: Reduced stats polling frequency to minimize overhead
        static let statsInterval: TimeInterval = 5.0  // Was 1.0s, now 5.0s
        static let statsLogDelay: TimeInterval = 2.0
    }

    private enum LoggingInterval {
        static let standardFrames = 60
    }

    // MARK: - Properties

    public var state: TransportState = .idle {
        didSet {
            if state != oldValue {
                onStateChange?(state)
            }
        }
    }

    public var onStateChange: ((TransportState) -> Void)?
    public var onStats: ((VideoTransportStats) -> Void)?

    private let logger = Logger(subsystem: "com.television.hippo", category: "WebRTC")

    // MARK: WebRTC Components

    private var peerConnectionFactory: LKRTCPeerConnectionFactory!
    private var peerConnection: LKRTCPeerConnection?
    private var videoSource: LKRTCVideoSource?
    private var videoTrack: LKRTCVideoTrack?
    private var videoSender: LKRTCRtpSender?
    private var videoCapturer: LKRTCVideoCapturer?

    // External signaling client (injected from ViewModel)
    private weak var signalingClient: SignalingClient?
    private let config: TransportConfig

    /// Callback when offer is created (for external signaling)
    public var onOfferCreated: ((String) -> Void)?
    /// Callback when ICE candidate is generated
    public var onIceCandidateGenerated: ((LKRTCIceCandidate) -> Void)?

    // MARK: Queues

    private let rtcQueue: DispatchQueue

    /// OPTIMIZED: Background queue for stats collection (low priority)
    private let statsQueue: DispatchQueue

    // MARK: Remote candidate queueing

    private var pendingRemoteCandidates: [LKRTCIceCandidate] = []
    private var remoteDescriptionSet: Bool = false

    // MARK: Stats tracking

    private var statsTimer: Timer?

    // P0.3: Disconnection timer for ICE restart
    private var disconnectionTimer: Timer?

    // MARK: Initialization

    public init(config: TransportConfig = .standard) {
        self.config = config
        self.rtcQueue = DispatchQueue(
            label: "com.television.hippo.webrtc",
            qos: .userInteractive
        )
        // OPTIMIZED: Stats collection on low-priority background queue
        self.statsQueue = DispatchQueue(
            label: "com.television.hippo.webrtc.stats",
            qos: .utility  // Low priority for non-critical stats
        )
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - ITransport

    // Static flag to ensure WebRTC is initialized only once
    private static var isWebRTCInitialized = false

    /// Start WebRTC with external signaling client
    /// - Parameter signalingClient: External SignalingClient managed by ViewModel
    public func start(with signalingClient: SignalingClient) throws {
        self.signalingClient = signalingClient

        logger.info("WebRTC starting with external signaling...")
        print("[WebRTCManager] Starting WebRTC transport with external signaling...")
        state = .connecting

        // 1. Initialize WebRTC factory (only once per app lifecycle)
        if !Self.isWebRTCInitialized {
            print("[WebRTCManager] Initializing WebRTC SSL and tracer (first time)...")
            LKRTCInitializeSSL()
            LKRTCSetupInternalTracer()
            Self.isWebRTCInitialized = true
        } else {
            print("[WebRTCManager] WebRTC already initialized, skipping SSL/tracer setup")
        }

        // Use HEVC encoder factory for better compression
        let encoderFactory = HEVCVideoEncoderFactory()
        let decoderFactory = LKRTCDefaultVideoDecoderFactory()

        peerConnectionFactory = LKRTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        print("[WebRTCManager] Peer connection factory created with HEVC support")

        // 2. Create peer connection
        print("[WebRTCManager] Creating peer connection...")
        try createPeerConnection()

        // 3. Create video track
        print("[WebRTCManager] Creating video track...")
        createVideoTrack()

        // 4. Create offer immediately (signaling is already connected)
        print("[WebRTCManager] Creating offer...")
        createOffer()

        logger.info("WebRTC initialized and offer created")
        print("[WebRTCManager] WebRTC initialization complete")
    }


    public func stop() {
        logger.info("WebRTC stopping...")

        // 1. Stop timers immediately
        statsTimer?.invalidate()
        statsTimer = nil

        disconnectionTimer?.invalidate()
        disconnectionTimer = nil

        // 2. Release video components
        videoCapturer = nil
        videoTrack = nil
        videoSource = nil
        videoSender = nil

        // 3. Clear signaling reference (don't disconnect - managed by ViewModel)
        signalingClient = nil

        // 4. Close peer connection in background (may block)
        if let pc = peerConnection {
            Task.detached {
                pc.close()
            }
        }
        peerConnection = nil

        // 5. Reset candidate state
        pendingRemoteCandidates.removeAll()
        remoteDescriptionSet = false
        frameCount = 0

        // 6. Don't cleanup WebRTC global state - it's shared and can only be initialized once
        // LKRTCShutdownInternalTracer() and LKRTCCleanupSSL() cause crash if called before re-init

        state = .closed
        logger.info("✅ WebRTC stopped")
    }

    public func sendControl(_ data: Data) {
        logger.debug("Control data: \(data.count) bytes")
    }

    // MARK: - IVideoTransport

    public func send(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard state == .connected else {
            logger.debug("Skipping send - not connected, state: \(String(describing: self.state))")
            return
        }

        guard let capturer = videoCapturer else {
            logger.error("videoCapturer is nil")
            return
        }

        guard let videoSource = videoSource else {
            logger.error("videoSource is nil")
            return
        }

        guard let videoTrack = videoTrack else {
            logger.error("videoTrack is nil")
            return
        }

        // Check track state
        if !videoTrack.isEnabled {
            logger.warning("videoTrack is disabled!")
        }

        let timeStampNs = CMTimeGetSeconds(presentationTime) * 1_000_000_000
        let rtcPixelBuffer = LKRTCCVPixelBuffer(pixelBuffer: pixelBuffer)

        let videoFrame = LKRTCVideoFrame(
            buffer: rtcPixelBuffer,
            rotation: ._0,
            timeStampNs: Int64(timeStampNs)
        )

        // Push frame to video source using reusable capturer
        videoSource.capturer(capturer, didCapture: videoFrame)

        frameCount += 1

        // Periodic counter reset
        if frameCount >= frameCounterResetInterval {
            logger.info("🔄 Resetting WebRTC frame counter (sent: \(self.frameCount))")
            frameCount = 0
        }

        // Log periodically (less frequently)
        if frameCount % (LoggingInterval.standardFrames * 5) == 0 {
            logger.debug("Sent \(self.frameCount) frames to videoSource, track enabled: \(videoTrack.isEnabled)")
        }
    }

    private var frameCount: Int = 0
    private let frameCounterResetInterval: Int = 18000  // Reset every 18000 frames (10 minutes at 30fps)

    // MARK: - Private: Peer Connection

    private func createPeerConnection() throws {
        let rtcConfig = LKRTCConfiguration()

        rtcConfig.iceServers = config.stunServers.map { url in
            LKRTCIceServer(urlStrings: [url])
        }

        rtcConfig.sdpSemantics = .unifiedPlan

        let constraints = LKRTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        guard let pc = peerConnectionFactory.peerConnection(with: rtcConfig, constraints: constraints, delegate: self) else {
            throw VideoError.peerConnectionFailed(reason: "Failed to create peer connection")
        }

        self.peerConnection = pc
        logger.info("Peer connection created")
    }

    private func createVideoTrack() {
        videoSource = peerConnectionFactory.videoSource()

        // Create capturer once and reuse it
        videoCapturer = LKRTCVideoCapturer(delegate: videoSource!)

        let videoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "video0")
        videoTrack.isEnabled = true  // Ensure track is enabled
        self.videoTrack = videoTrack

        logger.info("Video track created: id=\(videoTrack.trackId), enabled=\(videoTrack.isEnabled)")

        if let sender = peerConnection?.add(videoTrack, streamIds: ["stream0"]) {
            self.videoSender = sender

            // P0.1: Configure encoding with downsample factor
            try? configureEncodingParameters(sender: sender)

            logger.info("Video track added with capturer, track enabled: \(videoTrack.isEnabled)")
        }
    }

    /// Create and send a new WebRTC offer (public for renegotiation)
    public func createOffer() {
        print("[WebRTCManager] Creating offer (signaling state: \(signalingClient?.state.self ?? .disconnected))")

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["OfferToReceiveVideo": "false"]
        )

        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp, error == nil else {
                self?.logger.error("Failed to create offer: \(error?.localizedDescription ?? "unknown")")
                print("[WebRTCManager] Failed to create offer: \(error?.localizedDescription ?? "unknown")")
                return
            }

            print("[WebRTCManager] Offer created successfully")

            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    self.logger.error("Failed to set local description: \(error.localizedDescription)")
                    print("[WebRTCManager] Failed to set local description: \(error.localizedDescription)")
                    return
                }

                self.logger.info("Local description set (offer)")
                print("[WebRTCManager] Local description set (offer)")

                print("[WebRTCManager] Sending offer to receiver...")
                self.signalingClient?.send(offer: sdp.sdp)
                print("[WebRTCManager] Offer sent successfully")
            }
        }
    }

    // MARK: - P0.1: Encoding Configuration

    private func configureEncodingParameters(sender: LKRTCRtpSender) throws {
        let parameters = sender.parameters
        guard !parameters.encodings.isEmpty else {
            throw VideoError.invalidConfiguration(reason: "No encoding parameters")
        }

        let encoding = parameters.encodings[0]

        // OPTIMIZED: Bitrate configuration for medical streaming
        encoding.maxBitrateBps = NSNumber(value: config.maxBitrate)
        encoding.minBitrateBps = NSNumber(value: config.minBitrate)

        // OPTIMIZED: Cap at 30fps for Half SBS 1/4 mode (balance quality vs bandwidth)
        encoding.maxFramerate = NSNumber(value: 30)  // Was 60, now 30 for optimization

        // OPTIMIZED: Adaptive bitrate for network fluctuations
        encoding.networkPriority = .high

        // P0.1: Use configurable downsample factor
        let factor = Double(config.resolutionDownsampleFactor)
        encoding.scaleResolutionDownBy = NSNumber(value: factor)

        encoding.isActive = true

        parameters.encodings[0] = encoding
        sender.parameters = parameters

        logger.info("""
        ⚙️ OPTIMIZED Encoding configured:
           Target: \(self.config.targetBitrate / 1_000_000) Mbps
           Max: \(self.config.maxBitrate / 1_000_000) Mbps
           Min: \(self.config.minBitrate / 1_000_000) Mbps
           Max FPS: 30 (optimized for Half SBS 1/4)
           Downsample: \(factor)x
           Network Priority: High
        """)
    }

    // MARK: - P0.3: ICE Restart

    private func attemptIceRestart() {
        logger.info("Performing ICE restart...")

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: ["IceRestart": "true"],
            optionalConstraints: nil
        )

        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                self?.logger.error("ICE restart offer failed: \(error?.localizedDescription ?? "unknown")")
                return
            }

            self.peerConnection?.setLocalDescription(sdp) { _ in
                self.signalingClient?.send(offer: sdp.sdp)
                self.logger.info("ICE restart offer sent")
            }
        }
    }

    private func startDisconnectionTimer() {
        disconnectionTimer?.invalidate()

        disconnectionTimer = Timer.scheduledTimer(withTimeInterval: ConnectionConstants.disconnectionGracePeriod, repeats: false) { [weak self] _ in
            self?.logger.warning("Connection not recovered after \(ConnectionConstants.disconnectionGracePeriod)s, restarting...")
            self?.attemptIceRestart()
        }
    }

    private func cancelDisconnectionTimer() {
        disconnectionTimer?.invalidate()
        disconnectionTimer = nil
    }

    // MARK: - Public: Signaling Message Handlers

    /// Handle SDP answer from remote peer (called by ViewModel)
    public func handleAnswer(sdp: String) {
        print("📄 SDP Answer received")
        let sessionDescription = LKRTCSessionDescription(type: .answer, sdp: sdp)

        peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("Failed to set remote description: \(error.localizedDescription)")
                return
            }

            self.logger.info("Remote description set (answer)")
            self.remoteDescriptionSet = true

            // Process pending ICE candidates
            for candidate in self.pendingRemoteCandidates {
                self.peerConnection?.add(candidate) { error in
                    if let error = error {
                        self.logger.error("Failed to add ICE candidate: \(error.localizedDescription)")
                    }
                }
            }
            self.pendingRemoteCandidates.removeAll()
        }
    }

    /// Handle remote ICE candidate (called by ViewModel)
    public func handleRemoteCandidate(candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        let iceCandidate = LKRTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)

        if remoteDescriptionSet {
            peerConnection?.add(iceCandidate) { [weak self] error in
                if let error = error {
                    self?.logger.error("Failed to add ICE candidate: \(error.localizedDescription)")
                }
            }
        } else {
            pendingRemoteCandidates.append(iceCandidate)
        }
    }
}

// MARK: - LKRTCPeerConnectionDelegate

extension WebRTCManager: LKRTCPeerConnectionDelegate {

    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        logger.info("ICE_STATE: \(newState.rawValue)")

        switch newState {
        case .connected, .completed:
            state = .connected
            cancelDisconnectionTimer()

            // OPTIMIZED: Log stats on background queue after connection
            statsQueue.asyncAfter(deadline: .now() + ConnectionConstants.statsLogDelay) { [weak self] in
                self?.peerConnection?.statistics { report in
                    for (key, value) in report.statistics {
                        let valueStr = String(describing: value)
                        if valueStr.contains("outbound-rtp") {
                            print("Mac Stats: \(key) = \(value)")
                        }
                    }
                }
            }

        case .disconnected:
            logger.warning("ICE_STATE:disconnected, monitoring for recovery...")
            startDisconnectionTimer()  // P0.3: Start grace period

        case .failed:
            logger.error("ICE_STATE:failed, attempting ICE restart...")
            attemptIceRestart()  // P0.3: Auto restart

        case .closed:
            state = .closed

        default:
            break
        }
    }

    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didGenerate candidate: LKRTCIceCandidate) {
        signalingClient?.send(iceCandidate: candidate)
    }

    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCSignalingState) {
        logger.info("Signaling state: \(newState.rawValue)")
    }

    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd stream: LKRTCMediaStream) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove stream: LKRTCMediaStream) {}
    public func peerConnectionShouldNegotiate(_ peerConnection: LKRTCPeerConnection) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCPeerConnectionState) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove candidates: [LKRTCIceCandidate]) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didOpen dataChannel: LKRTCDataChannel) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceGatheringState) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didAdd rtpReceiver: LKRTCRtpReceiver, streams mediaStreams: [LKRTCMediaStream]) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didRemove rtpReceiver: LKRTCRtpReceiver) {}
    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didStartReceivingOn transceiver: LKRTCRtpTransceiver) {}
}

