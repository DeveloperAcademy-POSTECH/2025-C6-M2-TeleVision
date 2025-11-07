//
//  SignalingClient.swift
//  Hippo
//
//  WebSocket-based signaling client for WebRTC
//  Enhanced with P0.3: Automatic reconnection with exponential backoff
//

import Foundation
import os.log
import LiveKitWebRTC

// MARK: - Signaling Message

enum SignalingMessage: Codable {
    case offer(sdp: String)
    case answer(sdp: String)
    case iceCandidate(candidate: String, sdpMid: String?, sdpMLineIndex: Int32)

    enum CodingKeys: String, CodingKey {
        case type, sdp, candidate, sdpMid, sdpMLineIndex
    }

    enum MessageType: String, Codable {
        case offer, answer, iceCandidate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .offer:
            let sdp = try container.decode(String.self, forKey: .sdp)
            self = .offer(sdp: sdp)
        case .answer:
            let sdp = try container.decode(String.self, forKey: .sdp)
            self = .answer(sdp: sdp)
        case .iceCandidate:
            let candidate = try container.decode(String.self, forKey: .candidate)
            let sdpMid = try container.decodeIfPresent(String.self, forKey: .sdpMid)
            let sdpMLineIndex = try container.decode(Int32.self, forKey: .sdpMLineIndex)
            self = .iceCandidate(candidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .offer(let sdp):
            try container.encode(MessageType.offer, forKey: .type)
            try container.encode(sdp, forKey: .sdp)
        case .answer(let sdp):
            try container.encode(MessageType.answer, forKey: .type)
            try container.encode(sdp, forKey: .sdp)
        case .iceCandidate(let candidate, let sdpMid, let sdpMLineIndex):
            try container.encode(MessageType.iceCandidate, forKey: .type)
            try container.encode(candidate, forKey: .candidate)
            try container.encodeIfPresent(sdpMid, forKey: .sdpMid)
            try container.encode(sdpMLineIndex, forKey: .sdpMLineIndex)
        }
    }
}

// MARK: - Signaling Delegate

protocol SignalingDelegate: AnyObject {
    func signalingClient(_ client: SignalingClient, didReceiveOffer sdp: String)
    func signalingClient(_ client: SignalingClient, didReceiveAnswer sdp: String)
    func signalingClient(_ client: SignalingClient, didReceiveCandidate candidate: String, sdpMid: String?, sdpMLineIndex: Int32)
    func signalingClientDidReceiveRenegotiate(_ client: SignalingClient)
    func signalingClientDidReceiveReceiverReady(_ client: SignalingClient)
    func signalingClient(_ client: SignalingClient, didChangeState state: SignalingState)
}

extension SignalingDelegate {
    func signalingClientDidReceiveRenegotiate(_ client: SignalingClient) {}
    func signalingClientDidReceiveReceiverReady(_ client: SignalingClient) {}
}

// MARK: - Signaling State

enum SignalingState {
    case disconnected
    case connecting
    case connected
    case failed
}

// MARK: - Signaling Client

/// WebSocket-based signaling client
/// P0.3 Enhancement: Automatic reconnection with exponential backoff
final class SignalingClient {

    // MARK: Properties

    weak var delegate: SignalingDelegate?

    private let serverURL: URL
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession

    private let logger = Logger(subsystem: "com.television.hippo", category: "Signaling")

    private(set) var state: SignalingState = .disconnected {
        didSet {
            if state != oldValue {
                delegate?.signalingClient(self, didChangeState: state)
            }
        }
    }

    // P0.3: Reconnection support
    private let reconnectionPolicy: ReconnectionPolicy
    private var currentAttempt: Int = 0
    private var reconnectionTimer: Timer?
    private var currentRole: String = ""

    /// P0.3: Reconnection state
    private(set) var reconnectionState: ReconnectionState = .idle

    // MARK: Initialization

    init(serverURL: URL, reconnectionPolicy: ReconnectionPolicy = .standard) {
        self.serverURL = serverURL
        self.reconnectionPolicy = reconnectionPolicy

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        self.session = URLSession(configuration: config)
    }

    deinit {
        disconnect()
    }

    // MARK: - Public Methods

    func connect(as role: String) throws {
        guard state == .disconnected else {
            logger.warning("⚠️ Already connected or connecting")
            return
        }

        currentRole = role

        logger.info("🔌 Connecting to \(self.serverURL.absoluteString) as \(role)")

        state = .connecting

        // Create WebSocket task
        webSocketTask = session.webSocketTask(with: serverURL)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessage()

        // Register client role
        let registerMessage: [String: String] = [
            "type": "register",
            "role": role
        ]

        if let data = try? JSONSerialization.data(withJSONObject: registerMessage),
           let jsonString = String(data: data, encoding: .utf8) {
            let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
            webSocketTask?.send(wsMessage) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.error("❌ Registration failed: \(error.localizedDescription)")
                    self.handleConnectionFailure(error)
                } else {
                    self.logger.info("✅ Registered as '\(role)'")
                    self.state = .connected
                    self.resetReconnectionState()  // P0.3: Reset on success
                }
            }
        }
    }

    func disconnect() {
        cancelReconnection()  // P0.3: Cancel any pending reconnection
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        state = .disconnected
    }

    // MARK: - Sending Messages

    func send(offer sdp: String) {
        let message = SignalingMessage.offer(sdp: sdp)
        sendMessage(message)
    }

    func send(answer sdp: String) {
        let message = SignalingMessage.answer(sdp: sdp)
        sendMessage(message)
    }

    func send(iceCandidate candidate: LKRTCIceCandidate) {
        let message = SignalingMessage.iceCandidate(
            candidate: candidate.sdp,
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex
        )
        sendMessage(message)
    }

    private func sendMessage(_ message: SignalingMessage) {
        guard state == .connected else {
            logger.error("❌ Cannot send message: not connected")
            return
        }

        do {
            let data = try JSONEncoder().encode(message)
            if let jsonString = String(data: data, encoding: .utf8) {
                let wsMessage = URLSessionWebSocketTask.Message.string(jsonString)
                webSocketTask?.send(wsMessage) { [weak self] error in
                    if let error = error {
                        self?.logger.error("❌ Failed to send message: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            logger.error("❌ Failed to encode message: \(error.localizedDescription)")
        }
    }

    // MARK: - Receiving Messages

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleWebSocketMessage(message)
                self.receiveMessage()  // Continue receiving

            case .failure(let error):
                self.logger.error("❌ WebSocket error: \(error.localizedDescription)")
                self.handleConnectionFailure(error)
            }
        }
    }

    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else {
            logger.warning("⚠️ Received non-string message")
            return
        }

        guard let data = text.data(using: .utf8) else {
            logger.error("❌ Failed to convert message to data")
            return
        }

        // Try to decode as SignalingMessage
        if let signalingMsg = try? JSONDecoder().decode(SignalingMessage.self, from: data) {
            handleSignalingMessage(signalingMsg)
            return
        }

        // Try to decode as generic message (for "renegotiate", "receiver-ready", etc.)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            switch type {
            case "renegotiate":
                delegate?.signalingClientDidReceiveRenegotiate(self)
            case "receiver-ready":
                delegate?.signalingClientDidReceiveReceiverReady(self)
            default:
                logger.warning("⚠️ Unknown message type: \(type)")
            }
        }
    }

    private func handleSignalingMessage(_ message: SignalingMessage) {
        switch message {
        case .offer(let sdp):
            delegate?.signalingClient(self, didReceiveOffer: sdp)
        case .answer(let sdp):
            delegate?.signalingClient(self, didReceiveAnswer: sdp)
        case .iceCandidate(let candidate, let sdpMid, let sdpMLineIndex):
            delegate?.signalingClient(self, didReceiveCandidate: candidate, sdpMid: sdpMid, sdpMLineIndex: sdpMLineIndex)
        }
    }

    // MARK: - P0.3: Automatic Reconnection

    private func handleConnectionFailure(_ error: Error) {
        state = .failed

        guard self.reconnectionPolicy.canRetry(currentAttempt: self.currentAttempt) else {
            logger.error("❌ Max reconnection attempts reached (\(self.reconnectionPolicy.maxAttempts))")
            reconnectionState = .exhausted
            return
        }

        currentAttempt += 1
        let delay = self.reconnectionPolicy.delay(forAttempt: self.currentAttempt - 1)

        reconnectionState = .reconnecting(attempt: self.currentAttempt, nextRetryIn: delay)

        logger.info("""
        🔄 Reconnection attempt \(self.currentAttempt)/\(self.reconnectionPolicy.maxAttempts) \
        in \(String(format: "%.1f", delay))s
        """)

        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            self.logger.info("🔄 Attempting reconnection...")
            self.state = .disconnected  // Reset state

            do {
                try self.connect(as: self.currentRole)
            } catch {
                self.logger.error("❌ Reconnection failed: \(error.localizedDescription)")
                self.handleConnectionFailure(error)
            }
        }
    }

    private func resetReconnectionState() {
        currentAttempt = 0
        reconnectionState = .idle
        cancelReconnectionTimer()
    }

    func cancelReconnection() {
        cancelReconnectionTimer()
        currentAttempt = 0
        reconnectionState = .idle
    }

    private func cancelReconnectionTimer() {
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
    }
}
