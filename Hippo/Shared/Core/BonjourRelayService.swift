//
//  BonjourRelayService.swift
//  Hippo
//
//  TCP Relay service for Bonjour discovery fallback
//  - Provides discovered endpoints via TCP connection
//  - Useful when mDNS is blocked/unstable (KT hotspot scenarios)
//  - Clients can connect to this relay to get server list
//

import Foundation
import Network
import os.log
import Combine

// MARK: - Endpoint Info Model

/// Represents a discovered endpoint that can be serialized and transmitted
public struct EndpointInfo: Codable, Identifiable, Sendable {
    public let id: String
    public let host: String
    public let port: Int
    public let name: String
    public let isValidated: Bool
    public let timestamp: Date

    public init(id: String = UUID().uuidString, host: String, port: Int, name: String, isValidated: Bool = false, timestamp: Date = Date()) {
        self.id = id
        self.host = host
        self.port = port
        self.name = name
        self.isValidated = isValidated
        self.timestamp = timestamp
    }
}

// MARK: - Relay Response Model

/// Response structure for relay requests
public struct BonjourRelayResponse: Sendable {
    public let endpoints: [EndpointInfo]
    public let timestamp: Date
    public let version: String

    public init(endpoints: [EndpointInfo], timestamp: Date = Date(), version: String = "1.0") {
        self.endpoints = endpoints
        self.timestamp = timestamp
        self.version = version
    }
}

// MARK: - Codable Conformance (nonisolated extension)

extension BonjourRelayResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case endpoints
        case timestamp
        case version
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        endpoints = try container.decode([EndpointInfo].self, forKey: .endpoints)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        version = try container.decode(String.self, forKey: .version)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(endpoints, forKey: .endpoints)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(version, forKey: .version)
    }
}

// MARK: - Bonjour Relay Service

@MainActor
public final class BonjourRelayService: ObservableObject {

    // MARK: - Published Properties

    @Published public var isRunning: Bool = false
    @Published public var connectedClients: Int = 0

    // MARK: - Configuration

    /// TCP port for relay service (default: 53530)
    public var relayPort: UInt16 = 53530

    /// Maximum number of concurrent client connections
    public var maxConnections: Int = 10

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.television.hippo", category: "BonjourRelay")
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.television.hippo.BonjourRelay", qos: .userInitiated)

    /// Current list of discovered endpoints to serve to clients
    private var endpoints: [EndpointInfo] = []

    /// Active client connections
    private var activeConnections: Set<UUID> = []

    // MARK: - Initialization

    public init(port: UInt16 = 53530) {
        self.relayPort = port
    }

    // MARK: - Public API

    /// Start the TCP relay service
    public func start() {
        guard !isRunning else {
            logger.warning("[BonjourRelay] ⚠️ Relay service already running")
            return
        }

        do {
            logger.info("[BonjourRelay] 🚀 Starting relay service on port \(self.relayPort)")

            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            params.acceptLocalOnly = true // Only accept connections from local network

            // Create listener
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: relayPort)!)

            listener?.stateUpdateHandler = { [weak self] newState in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    switch newState {
                    case .ready:
                        self.logger.info("[BonjourRelay] ✅ Relay service ready on port \(self.relayPort)")
                        self.isRunning = true

                    case .failed(let error):
                        self.logger.error("[BonjourRelay] ❌ Relay service failed: \(error.localizedDescription)")
                        self.isRunning = false

                    case .cancelled:
                        self.logger.info("[BonjourRelay] 🛑 Relay service cancelled")
                        self.isRunning = false

                    case .waiting(let error):
                        self.logger.warning("[BonjourRelay] ⏳ Relay service waiting: \(error.localizedDescription)")

                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                Task { @MainActor [weak self] in
                    self?.handleNewConnection(connection)
                }
            }

            listener?.start(queue: queue)

        } catch {
            logger.error("[BonjourRelay] ❌ Failed to start relay service: \(error.localizedDescription)")
            isRunning = false
        }
    }

    /// Stop the TCP relay service
    public func stop() {
        logger.info("[BonjourRelay] 🛑 Stopping relay service")

        listener?.cancel()
        listener = nil

        Task { @MainActor in
            isRunning = false
            connectedClients = 0
            activeConnections.removeAll()
        }
    }

    /// Update the list of endpoints to serve to clients
    /// This should be called by BonjourServiceDiscovery when new services are discovered
    public func updateEndpoints(_ newEndpoints: [EndpointInfo]) {
        endpoints = newEndpoints
        logger.info("[BonjourRelay] 📋 Updated endpoint list: \(newEndpoints.count) endpoint(s)")

        for endpoint in newEndpoints {
            logger.debug("[BonjourRelay]   - \(endpoint.name): \(endpoint.host):\(endpoint.port) (validated: \(endpoint.isValidated))")
        }
    }

    /// Add a single endpoint
    public func addEndpoint(_ endpoint: EndpointInfo) {
        // Remove any existing endpoint with the same host:port
        endpoints.removeAll { $0.host == endpoint.host && $0.port == endpoint.port }
        endpoints.append(endpoint)

        logger.info("[BonjourRelay] ➕ Added endpoint: \(endpoint.host):\(endpoint.port)")
    }

    /// Remove an endpoint
    public func removeEndpoint(host: String, port: Int) {
        let beforeCount = endpoints.count
        endpoints.removeAll { $0.host == host && $0.port == port }
        let afterCount = endpoints.count

        if beforeCount != afterCount {
            logger.info("[BonjourRelay] 🗑️ Removed endpoint: \(host):\(port)")
        }
    }

    /// Clear all endpoints
    public func clearEndpoints() {
        logger.info("[BonjourRelay] 🗑️ Clearing all endpoints")
        endpoints.removeAll()
    }

    // MARK: - Private Methods

    private func handleNewConnection(_ connection: NWConnection) {
        let connectionId = UUID()

        // Check if we've reached max connections
        Task { @MainActor in
            if activeConnections.count >= maxConnections {
                logger.warning("[BonjourRelay] ⚠️ Max connections reached, rejecting new connection")
                connection.cancel()
                return
            }

            activeConnections.insert(connectionId)
            connectedClients = activeConnections.count
        }

        logger.info("[BonjourRelay] 🔌 New client connection: \(connectionId)")

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    self.logger.info("[BonjourRelay] ✅ Client connected: \(connectionId)")
                    self.sendEndpointsToConnection(connection, connectionId: connectionId)

                case .failed(let error):
                    self.logger.error("[BonjourRelay] ❌ Client connection failed: \(error.localizedDescription)")
                    self.cleanupConnection(connectionId)

                case .cancelled:
                    self.logger.info("[BonjourRelay] 🛑 Client connection cancelled: \(connectionId)")
                    self.cleanupConnection(connectionId)

                default:
                    break
                }
            }
        }

        connection.start(queue: queue)
    }

    private func sendEndpointsToConnection(_ connection: NWConnection, connectionId: UUID) {
        logger.info("[BonjourRelay] 📤 Sending \(self.endpoints.count) endpoint(s) to client: \(connectionId)")

        let response = BonjourRelayResponse(endpoints: endpoints)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            let jsonData = try encoder.encode(response)

            // Add newline delimiter for easier parsing
            var dataToSend = jsonData
            dataToSend.append(contentsOf: "\n".utf8)

            logger.debug("[BonjourRelay] 📦 Payload size: \(dataToSend.count) bytes")

            connection.send(content: dataToSend, completion: .contentProcessed { [weak self] error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if let error = error {
                        self.logger.error("[BonjourRelay] ❌ Failed to send data: \(error.localizedDescription)")
                    } else {
                        self.logger.info("[BonjourRelay] ✅ Successfully sent endpoints to client: \(connectionId)")
                    }

                    // Close connection after sending
                    connection.cancel()
                    self.cleanupConnection(connectionId)
                }
            })

        } catch {
            logger.error("[BonjourRelay] ❌ Failed to encode endpoints: \(error.localizedDescription)")
            connection.cancel()
            cleanupConnection(connectionId)
        }
    }

    private func cleanupConnection(_ connectionId: UUID) {
        activeConnections.remove(connectionId)
        connectedClients = activeConnections.count
        logger.debug("[BonjourRelay] 🧹 Cleaned up connection: \(connectionId) (active: \(self.activeConnections.count))")
    }

    // MARK: - Deinitialization

    nonisolated deinit {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }
}

// MARK: - Thread-safe Box for captured variables

/// Thread-safe box for mutable values captured in concurrent contexts
private final class SendableBox<T>: @unchecked Sendable {
    private nonisolated(unsafe) var value: T
    private let lock = NSLock()

    nonisolated init(_ value: T) {
        self.value = value
    }

    nonisolated func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    nonisolated func set(_ newValue: T) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }

    nonisolated func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

// MARK: - Client Helper (Vision Pro Side)

/// Helper class for Vision Pro to connect to Mac's BonjourRelayService
public final class BonjourRelayClient {

    private let logger = Logger(subsystem: "com.television.hippo", category: "BonjourRelayClient")

    /// Fetch endpoints from a relay server
    /// - Parameters:
    ///   - host: Relay server host (e.g., Mac's IP address)
    ///   - port: Relay server port (default: 53530)
    ///   - timeout: Connection timeout in seconds
    /// - Returns: Array of discovered endpoints
    public func fetchEndpoints(from host: String, port: UInt16 = 53530, timeout: TimeInterval = 5.0) async throws -> [EndpointInfo] {
        logger.info("[BonjourRelayClient] 🔍 Fetching endpoints from \(host):\(port)")

        // Create connection to relay server
        guard let ipAddress = IPv4Address(host) else {
            throw RelayClientError.invalidHost(host)
        }

        let endpoint = NWEndpoint.hostPort(host: .ipv4(ipAddress), port: NWEndpoint.Port(rawValue: port)!)
        let connection = NWConnection(to: endpoint, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            let hasResumed = SendableBox(false)

            // Set up timeout
            let timeoutTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))

                if !hasResumed.get() {
                    hasResumed.set(true)
                    connection.cancel()
                    continuation.resume(throwing: RelayClientError.timeout)
                }
            }

            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }

                switch state {
                case .ready:
                    self.logger.info("[BonjourRelayClient] ✅ Connected to relay server")

                    // Receive data
                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { content, _, isComplete, error in
                        timeoutTask.cancel()

                        if let error = error {
                            if !hasResumed.get() {
                                hasResumed.set(true)
                                self.logger.error("[BonjourRelayClient] ❌ Receive error: \(error.localizedDescription)")
                                continuation.resume(throwing: RelayClientError.receiveError(error))
                            }
                            connection.cancel()
                            return
                        }

                        guard let data = content else {
                            if !hasResumed.get() {
                                hasResumed.set(true)
                                self.logger.error("[BonjourRelayClient] ❌ No data received")
                                continuation.resume(throwing: RelayClientError.noDataReceived)
                            }
                            connection.cancel()
                            return
                        }

                        // Parse JSON response
                        do {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601

                            let response = try decoder.decode(BonjourRelayResponse.self, from: data)

                            if !hasResumed.get() {
                                hasResumed.set(true)
                                self.logger.info("[BonjourRelayClient] 📦 Received \(response.endpoints.count) endpoint(s)")
                                continuation.resume(returning: response.endpoints)
                            }

                        } catch {
                            if !hasResumed.get() {
                                hasResumed.set(true)
                                self.logger.error("[BonjourRelayClient] ❌ Failed to decode response: \(error.localizedDescription)")
                                continuation.resume(throwing: RelayClientError.decodingError(error))
                            }
                        }

                        connection.cancel()
                    }

                case .failed(let error):
                    timeoutTask.cancel()
                    if !hasResumed.get() {
                        hasResumed.set(true)
                        self.logger.error("[BonjourRelayClient] ❌ Connection failed: \(error.localizedDescription)")
                        continuation.resume(throwing: RelayClientError.connectionFailed(error))
                    }
                    connection.cancel()

                case .cancelled:
                    timeoutTask.cancel()
                    if !hasResumed.get() {
                        hasResumed.set(true)
                        self.logger.info("[BonjourRelayClient] 🛑 Connection cancelled")
                        continuation.resume(throwing: RelayClientError.cancelled)
                    }

                default:
                    break
                }
            }

            connection.start(queue: DispatchQueue(label: "BonjourRelayClient", qos: .userInitiated))
        }
    }

    // MARK: - Error Types

    public enum RelayClientError: Error, LocalizedError {
        case invalidHost(String)
        case timeout
        case connectionFailed(Error)
        case receiveError(Error)
        case noDataReceived
        case decodingError(Error)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .invalidHost(let host):
                return "Invalid host address: \(host)"
            case .timeout:
                return "Connection timeout"
            case .connectionFailed(let error):
                return "Connection failed: \(error.localizedDescription)"
            case .receiveError(let error):
                return "Receive error: \(error.localizedDescription)"
            case .noDataReceived:
                return "No data received from relay server"
            case .decodingError(let error):
                return "Failed to decode response: \(error.localizedDescription)"
            case .cancelled:
                return "Connection cancelled"
            }
        }
    }
}

// MARK: - Integration Extension for BonjourServiceDiscovery

extension BonjourServiceDiscovery {
    /// Convert discovered servers to EndpointInfo array for relay service
    public func getEndpointInfoList() -> [EndpointInfo] {
        return discoveredServers.compactMap { server in
            guard let host = server.host, let port = server.port else {
                return nil
            }

            return EndpointInfo(
                host: host,
                port: port,
                name: server.name,
                isValidated: server.isValidated
            )
        }
    }

    /// Sync discovered servers to a relay service
    public func syncToRelayService(_ relayService: BonjourRelayService) {
        let endpoints = getEndpointInfoList()
        relayService.updateEndpoints(endpoints)
    }
}
