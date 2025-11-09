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

    // MARK: Properties

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

    private var signalingClient: SignalingClient?
    private let config: TransportConfig

    // MARK: Queues

    private let rtcQueue: DispatchQueue

    // MARK: Remote candidate queueing

    private var pendingRemoteCandidates: [LKRTCIceCandidate] = []
    private var remoteDescriptionSet: Bool = false

    // MARK: Stats tracking

    private var statsTimer: Timer?
    private let statsInterval: TimeInterval = 1.0

    // P0.3: Disconnection timer for ICE restart
    private var disconnectionTimer: Timer?
    private let disconnectionGracePeriod: TimeInterval = 10.0

    // MARK: Initialization

    public init(config: TransportConfig = .standard) {
        self.config = config
        self.rtcQueue = DispatchQueue(
            label: "com.television.hippo.webrtc",
            qos: .userInteractive
        )
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - ITransport

    public func start() throws {
        logger.info("🚀 WebRTC starting...")
        print("🚀 [WebRTCManager] Starting WebRTC transport...")
        state = .connecting

        // 1. Initialize WebRTC factory
        print("🔧 [WebRTCManager] Initializing WebRTC SSL and tracer...")
        LKRTCInitializeSSL()
        LKRTCSetupInternalTracer()

        // Use HEVC encoder factory for better compression
        let encoderFactory = HEVCVideoEncoderFactory()
        let decoderFactory = LKRTCDefaultVideoDecoderFactory()

        peerConnectionFactory = LKRTCPeerConnectionFactory(
            encoderFactory: encoderFactory,
            decoderFactory: decoderFactory
        )
        print("✅ [WebRTCManager] Peer connection factory created with HEVC support")

        // 2. Setup signaling FIRST (before creating peer connection)
        let serverURL = URL(string: "ws://127.0.0.1:8080")!
        print("📡 [WebRTCManager] Creating SignalingClient for: \(serverURL.absoluteString)")
        signalingClient = SignalingClient(serverURL: serverURL)
        signalingClient?.delegate = self

        print("📡 [WebRTCManager] Connecting to signaling server as 'sender'...")
        try signalingClient?.connect(as: "sender")

        // 3. Create peer connection (but DON'T create offer yet)
        print("🔗 [WebRTCManager] Creating peer connection...")
        try createPeerConnection()

        // 4. Create video track
        print("🎥 [WebRTCManager] Creating video track...")
        createVideoTrack()

        // 5. Offer will be created in signalingClient(_:didChangeState:) when connected
        print("⏳ [WebRTCManager] Waiting for signaling connection before creating offer...")

        logger.info("✅ WebRTC initialized (waiting for signaling)")
        print("✅ [WebRTCManager] WebRTC initialization complete (waiting for signaling)")
    }

    public func stop() {
        logger.info("🛑 WebRTC stopping...")

        statsTimer?.invalidate()
        statsTimer = nil

        disconnectionTimer?.invalidate()
        disconnectionTimer = nil

        videoCapturer = nil
        videoTrack = nil
        videoSource = nil
        videoSender = nil

        peerConnection?.close()
        peerConnection = nil

        signalingClient?.disconnect()
        signalingClient = nil

        LKRTCShutdownInternalTracer()
        LKRTCCleanupSSL()

        state = .closed
        logger.info("✅ WebRTC stopped")
    }

    public func sendControl(_ data: Data) {
        logger.debug("📤 Control data: \(data.count) bytes")
    }

    // MARK: - IVideoTransport

    public func send(pixelBuffer: CVPixelBuffer, presentationTime: CMTime) {
        guard state == .connected else {
            logger.debug("⏸️ Skipping send - not connected")
            return
        }

        guard let capturer = videoCapturer else {
            logger.error("❌ videoCapturer is nil")
            return
        }

        guard let videoSource = videoSource else {
            logger.error("❌ videoSource is nil")
            return
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
        logger.debug("📤 Frame sent: \(CVPixelBufferGetWidth(pixelBuffer))×\(CVPixelBufferGetHeight(pixelBuffer))")
    }

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
        logger.info("✅ Peer connection created")
    }

    private func createVideoTrack() {
        videoSource = peerConnectionFactory.videoSource()

        // Create capturer once and reuse it
        videoCapturer = LKRTCVideoCapturer(delegate: videoSource!)

        let videoTrack = peerConnectionFactory.videoTrack(with: videoSource!, trackId: "video0")
        videoTrack.isEnabled = true  // Ensure track is enabled
        self.videoTrack = videoTrack

        logger.info("📹 Video track created: id=\(videoTrack.trackId), enabled=\(videoTrack.isEnabled)")

        if let sender = peerConnection?.add(videoTrack, streamIds: ["stream0"]) {
            self.videoSender = sender

            // P0.1: Configure encoding with downsample factor
            try? configureEncodingParameters(sender: sender)

            logger.info("✅ Video track added with capturer, track enabled: \(videoTrack.isEnabled)")
        }
    }

    private func createOffer() {
        print("📝 [WebRTCManager] Creating offer (signaling state: \(signalingClient?.state.self ?? .disconnected))")

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["OfferToReceiveVideo": "false"]
        )

        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp, error == nil else {
                self?.logger.error("❌ Failed to create offer: \(error?.localizedDescription ?? "unknown")")
                print("❌ [WebRTCManager] Failed to create offer: \(error?.localizedDescription ?? "unknown")")
                return
            }

            print("✅ [WebRTCManager] Offer created successfully")
            print("📄 SDP Offer:\n\(sdp.sdp)")

            self.peerConnection?.setLocalDescription(sdp) { error in
                if let error = error {
                    self.logger.error("❌ Failed to set local description: \(error.localizedDescription)")
                    print("❌ [WebRTCManager] Failed to set local description: \(error.localizedDescription)")
                    return
                }

                self.logger.info("✅ Local description set (offer)")
                print("✅ [WebRTCManager] Local description set (offer)")

                print("📤 [WebRTCManager] Sending offer to receiver...")
                self.signalingClient?.send(offer: sdp.sdp)
                print("✅ [WebRTCManager] Offer sent successfully")
            }
        }
    }

    // MARK: - P0.1: Encoding Configuration

    private func configureEncodingParameters(sender: LKRTCRtpSender) throws {
        var parameters = sender.parameters
        guard !parameters.encodings.isEmpty else {
            throw VideoError.invalidConfiguration(reason: "No encoding parameters")
        }

        var encoding = parameters.encodings[0]

        encoding.maxBitrateBps = NSNumber(value: config.maxBitrate)
        encoding.minBitrateBps = NSNumber(value: config.minBitrate)
        encoding.maxFramerate = NSNumber(value: 60)

        // P0.1: Use configurable downsample factor
        let factor = Double(config.resolutionDownsampleFactor)
        encoding.scaleResolutionDownBy = NSNumber(value: factor)

        encoding.isActive = true

        parameters.encodings[0] = encoding
        sender.parameters = parameters

        logger.info("""
        🎛️ Encoding configured:
           Target: \(self.config.targetBitrate / 1_000_000) Mbps
           Max: \(self.config.maxBitrate / 1_000_000) Mbps
           Downsample: \(factor)x
        """)
    }

    // MARK: - P0.3: ICE Restart

    private func attemptIceRestart() {
        logger.info("🔄 Performing ICE restart...")

        let constraints = LKRTCMediaConstraints(
            mandatoryConstraints: ["IceRestart": "true"],
            optionalConstraints: nil
        )

        peerConnection?.offer(for: constraints) { [weak self] sdp, error in
            guard let self = self, let sdp = sdp else {
                self?.logger.error("❌ ICE restart offer failed: \(error?.localizedDescription ?? "unknown")")
                return
            }

            self.peerConnection?.setLocalDescription(sdp) { _ in
                self.signalingClient?.send(offer: sdp.sdp)
                self.logger.info("📤 ICE restart offer sent")
            }
        }
    }

    private func startDisconnectionTimer() {
        disconnectionTimer?.invalidate()

        disconnectionTimer = Timer.scheduledTimer(withTimeInterval: disconnectionGracePeriod, repeats: false) { [weak self] _ in
            self?.logger.warning("⚠️ Connection not recovered after \(self?.disconnectionGracePeriod ?? 0)s, restarting...")
            self?.attemptIceRestart()
        }
    }

    private func cancelDisconnectionTimer() {
        disconnectionTimer?.invalidate()
        disconnectionTimer = nil
    }
}

// MARK: - LKRTCPeerConnectionDelegate

extension WebRTCManager: LKRTCPeerConnectionDelegate {

    public func peerConnection(_ peerConnection: LKRTCPeerConnection, didChange newState: LKRTCIceConnectionState) {
        logger.info("🧊 ICE_STATE: \(newState.rawValue)")

        switch newState {
        case .connected, .completed:
            state = .connected
            cancelDisconnectionTimer()

            // Log stats after connection
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.peerConnection?.statistics { report in
                    print("📊 Mac WebRTC Stats: timestamp = \(report.timestamp_us), statistics = {")
                    for (key, value) in report.statistics {
                        let valueStr = String(describing: value)
                        if valueStr.contains("outbound-rtp") || valueStr.contains("inbound-rtp") ||
                           valueStr.contains("transport") || key.hasPrefix("T") {
                            print("    \"\(key)\" = \"\(value)\";")
                        }
                    }
                    print("}")
                }
            }

        case .disconnected:
            logger.warning("⚠️ ICE_STATE:disconnected, monitoring for recovery...")
            startDisconnectionTimer()  // P0.3: Start grace period

        case .failed:
            logger.error("❌ ICE_STATE:failed, attempting ICE restart...")
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
        logger.info("📶 Signaling state: \(newState.rawValue)")
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

// MARK: - SignalingDelegate

extension WebRTCManager: SignalingDelegate {

    func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String) {
        // Sender doesn't handle offers
    }

    func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String) {
        print("📄 SDP Answer received:\n\(sdp)")
        let sessionDescription = LKRTCSessionDescription(type: .answer, sdp: sdp)

        peerConnection?.setRemoteDescription(sessionDescription) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                self.logger.error("❌ Failed to set remote description: \(error.localizedDescription)")
                return
            }

            self.logger.info("✅ Remote description set (answer)")
            self.remoteDescriptionSet = true

            // Process pending ICE candidates
            for candidate in self.pendingRemoteCandidates {
                self.peerConnection?.add(candidate)
            }
            self.pendingRemoteCandidates.removeAll()
        }
    }

    func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: String, sdpMid: String?, sdpMLineIndex: Int32) {
        let iceCandidate = LKRTCIceCandidate(sdp: candidate, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)

        if remoteDescriptionSet {
            peerConnection?.add(iceCandidate)
        } else {
            pendingRemoteCandidates.append(iceCandidate)
        }
    }

    func signalingClient(_ client: SignalingClient, didChangeState state: SignalingState) {
        switch state {
        case .connected:
            logger.info("✅ Signaling connected")
            print("✅ [WebRTCManager] Signaling connected, now creating offer...")

            // Now that signaling is connected, create the offer
            createOffer()

        case .failed:
            self.state = .failed
        default:
            break
        }
    }
}
