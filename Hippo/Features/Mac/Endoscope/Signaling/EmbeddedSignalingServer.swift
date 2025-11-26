//
//  EmbeddedSignalingServer.swift
//  Hippo
//
//  Embedded WebSocket Signaling Server for Mac app
//  - Replaces the need for external `node server.js`
//  - Role-based client management (sender/receiver)
//  - Bonjour (mDNS) auto-discovery publishing
//

import Foundation
import Network
import os.log
import Combine

// MARK: - Embedded Signaling Server

@MainActor
public final class EmbeddedSignalingServer: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var state: SignalingServerState = .idle
    @Published public private(set) var connectedClients: Int = 0
    @Published public private(set) var hasSender: Bool = false
    @Published public private(set) var hasReceiver: Bool = false

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.television.hippo", category: "SignalingServer")
    private let configuration: SignalingServerConfiguration

    // Network components
    private var listener: NWListener?
    private let listenerQueue = DispatchQueue(label: "com.television.hippo.signaling", qos: .userInteractive)

    // Client management
    private var clients: [UUID: SignalingConnection] = [:]
    private var senderClient: SignalingConnection?
    private var receiverClient: SignalingConnection?

    // Heartbeat
    private var heartbeatTimer: Timer?

    // MARK: - Initialization

    public init(configuration: SignalingServerConfiguration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public API

    public func start() {
        // Don't start if already running or starting
        switch state {
        case .running, .starting:
            logger.info("Server already running or starting, skipping...")
            return
        case .idle, .stopped, .failed:
            break  // OK to start
        }

        state = .starting
        logger.info("🚀 Starting signaling server on port \(self.configuration.port)...")

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            // Enable WebSocket
            let wsOptions = NWProtocolWebSocket.Options()
            wsOptions.autoReplyPing = true
            parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: configuration.port)!)

            listener?.stateUpdateHandler = { [weak self] newState in
                Task { @MainActor [weak self] in
                    self?.handleListenerState(newState)
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }

            // Bonjour advertising
            listener?.service = NWListener.Service(
                name: configuration.serviceName,
                type: "_ws._tcp",
                txtRecord: NWTXTRecord(["service": "webrtc-signaling", "version": "1.0"])
            )

            listener?.start(queue: listenerQueue)
            startHeartbeat()

        } catch {
            logger.error("❌ Failed to start: \(error.localizedDescription)")
            state = .failed(error: error.localizedDescription)
        }
    }

    public func stop() {
        logger.info("🛑 Stopping signaling server...")

        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        for client in clients.values {
            client.connection.cancel()
        }
        clients.removeAll()
        senderClient = nil
        receiverClient = nil

        listener?.cancel()
        listener = nil

        state = .stopped
        connectedClients = 0
        hasSender = false
        hasReceiver = false
    }

    // MARK: - Listener State

    private func handleListenerState(_ newState: NWListener.State) {
        switch newState {
        case .ready:
            logger.info("✅ Server ready on port \(self.configuration.port)")
            state = .running(port: configuration.port)
            printServerInfo()

        case .failed(let error):
            logger.error("❌ Server failed: \(error.localizedDescription)")
            state = .failed(error: error.localizedDescription)

        case .cancelled:
            if case .running = state { state = .stopped }

        default:
            break
        }
    }

    private func printServerInfo() {
        print("")
        print("╔═══════════════════════════════════════════════╗")
        print("║   Embedded WebRTC Signaling Server Started    ║")
        print("╚═══════════════════════════════════════════════╝")
        print("   Port: \(configuration.port) | Bonjour: _ws._tcp")
        print("")
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        let client = SignalingConnection(connection: connection)
        clients[client.id] = client

        logger.info("🔌 New connection: \(client.id)")

        connection.stateUpdateHandler = { [weak self, weak client] state in
            guard let client = client else { return }
            Task { @MainActor [weak self] in
                if case .cancelled = state { self?.removeClient(client) }
                if case .failed = state { self?.removeClient(client) }
            }
        }

        connection.start(queue: listenerQueue)
        receiveMessage(from: client)
        updateClientCount()
    }

    private func removeClient(_ client: SignalingConnection) {
        logger.info("👋 Disconnected: \(client.displayName)")

        if client.role == "sender" {
            senderClient = nil
            hasSender = false
        } else if client.role == "receiver" {
            receiverClient = nil
            hasReceiver = false
        }

        clients.removeValue(forKey: client.id)
        updateClientCount()
    }

    private func updateClientCount() {
        connectedClients = clients.count
    }

    // MARK: - Message Handling

    private func receiveMessage(from client: SignalingConnection) {
        client.connection.receiveMessage { [weak self, weak client] content, context, _, error in
            guard let self = self, let client = client else { return }

            if error != nil { return }

            if let context = context,
               let metadata = context.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata {

                switch metadata.opcode {
                case .text:
                    if let data = content, let text = String(data: data, encoding: .utf8) {
                        Task { @MainActor in self.handleMessage(text, from: client) }
                    }
                case .pong:
                    Task { @MainActor in client.isAlive = true }
                case .close:
                    Task { @MainActor in self.removeClient(client) }
                    return
                default:
                    break
                }
            }

            self.receiveMessage(from: client)
        }
    }

    private func handleMessage(_ text: String, from client: SignalingConnection) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "register":
            handleRegister(json, from: client)
        case "offer":
            handleOffer(json)
        case "answer":
            handleAnswer(json)
        case "iceCandidate", "ice-candidate":
            handleIceCandidate(json, from: client)
        default:
            break
        }
    }

    // MARK: - Message Handlers

    private func handleRegister(_ json: [String: Any], from client: SignalingConnection) {
        guard let role = json["role"] as? String ?? json["clientId"] as? String else { return }

        client.role = role

        if role == "sender" {
            if let existing = senderClient {
                existing.connection.cancel()
                removeClient(existing)
            }
            senderClient = client
            hasSender = true
            logger.info("📱 SENDER registered")

            sendJSON(["type": "registered", "role": "sender"], to: client)

            if receiverClient != nil {
                sendJSON(["type": "ready", "message": "Receiver connected"], to: client)
            }

        } else if role == "receiver" {
            if let existing = receiverClient {
                existing.connection.cancel()
                removeClient(existing)
            }
            receiverClient = client
            hasReceiver = true
            logger.info("🥽 RECEIVER registered")

            sendJSON(["type": "registered", "role": "receiver"], to: client)

            if let sender = senderClient {
                sendJSON(["type": "ready", "message": "Receiver connected"], to: sender)
            }
        }
    }

    private func handleOffer(_ json: [String: Any]) {
        guard let sdp = json["sdp"] as? String,
              let receiver = receiverClient else { return }

        logger.info("📄 OFFER → receiver")
        sendJSON(["type": "offer", "sdp": sdp], to: receiver)
    }

    private func handleAnswer(_ json: [String: Any]) {
        guard let sdp = json["sdp"] as? String,
              let sender = senderClient else { return }

        logger.info("📄 ANSWER → sender")
        sendJSON(["type": "answer", "sdp": sdp], to: sender)
    }

    private func handleIceCandidate(_ json: [String: Any], from client: SignalingConnection) {
        guard let candidate = json["candidate"] as? String else { return }

        let sdpMid = json["sdpMid"] as? String
        let sdpMLineIndex = json["sdpMLineIndex"] as? Int32 ?? 0

        let target = (client === senderClient) ? receiverClient : senderClient
        guard let target = target else { return }

        client.iceCandidatesSent += 1

        if client.iceCandidatesSent % 5 == 0 {
            logger.info("🧊 ICE: \(client.iceCandidatesSent) candidates forwarded")
        }

        sendJSON([
            "type": "iceCandidate",
            "candidate": candidate,
            "sdpMid": sdpMid as Any,
            "sdpMLineIndex": sdpMLineIndex
        ], to: target)
    }

    // MARK: - Send Helper

    private func sendJSON(_ json: [String: Any], to client: SignalingConnection) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else { return }

        let metadata = NWProtocolWebSocket.Metadata(opcode: .text)
        let context = NWConnection.ContentContext(identifier: "text", metadata: [metadata])

        client.connection.send(
            content: text.data(using: .utf8),
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { _ in }
        )
    }

    // MARK: - Heartbeat

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: configuration.heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performHeartbeat()
            }
        }
    }

    private func performHeartbeat() {
        for client in clients.values {
            if !client.isAlive {
                client.connection.cancel()
                removeClient(client)
                continue
            }

            client.isAlive = false

            let metadata = NWProtocolWebSocket.Metadata(opcode: .ping)
            let context = NWConnection.ContentContext(identifier: "ping", metadata: [metadata])
            client.connection.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { _ in })
        }
    }
}
