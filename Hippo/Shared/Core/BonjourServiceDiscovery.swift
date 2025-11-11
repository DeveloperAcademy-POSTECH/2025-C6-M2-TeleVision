//
//  BonjourServiceDiscovery.swift
//  Hippo
//
//  Enhanced Bonjour (mDNS) service discovery with KT hotspot fallback support
//  - IP address filtering (proxy IP, loopback, link-local)
//  - Last known endpoint caching
//  - Retry mechanism with timeout control
//  - State-based discovery management
//

import Foundation
import Network
import os.log
import Combine

// MARK: - Discovery State

/// Represents the current state of Bonjour discovery
public enum BonjourDiscoveryState: Equatable {
    case idle
    case discovering
    case resolved(host: String, port: Int)
    case fallbackUsingLastEndpoint(host: String, port: Int)
    case failed(error: String)

    public static func == (lhs: BonjourDiscoveryState, rhs: BonjourDiscoveryState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.discovering, .discovering):
            return true
        case let (.resolved(lHost, lPort), .resolved(rHost, rPort)),
             let (.fallbackUsingLastEndpoint(lHost, lPort), .fallbackUsingLastEndpoint(rHost, rPort)):
            return lHost == rHost && lPort == rPort
        case let (.failed(lError), .failed(rError)):
            return lError == rError
        default:
            return false
        }
    }
}

// MARK: - Main Discovery Class

@MainActor
public final class BonjourServiceDiscovery: ObservableObject {

    // MARK: - Published Properties

    @Published public var discoveredServers: [DiscoveredServer] = []
    @Published public var isSearching: Bool = false
    @Published public var discoveryState: BonjourDiscoveryState = .idle

    // MARK: - Configuration

    /// Service type to browse (default: _ws._tcp for WebSocket/WebRTC signaling)
    public var serviceType: String = "_ws._tcp"

    /// Maximum number of resolution retry attempts
    public var maxRetryAttempts: Int = 3

    /// Timeout for service resolution (in seconds)
    public var resolutionTimeout: TimeInterval = 5.0

    /// Fallback timeout - if no services found within this time, use cached endpoint
    public var fallbackTimeout: TimeInterval = 10.0

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.television.hippo", category: "BonjourDiscovery")
    private var browser: NWBrowser?
    private var fallbackTimer: Task<Void, Never>?

    /// Cache for last successfully resolved endpoint
    private var lastKnownEndpoint: (host: String, port: Int)? {
        didSet {
            if let endpoint = lastKnownEndpoint {
                // Persist to UserDefaults for cross-session fallback
                UserDefaults.standard.set(endpoint.host, forKey: "LastKnownHost")
                UserDefaults.standard.set(endpoint.port, forKey: "LastKnownPort")
                logger.info("[Bonjour] 💾 Cached endpoint: \(endpoint.host):\(endpoint.port)")
            }
        }
    }

    /// Track resolution attempts per service
    private var resolutionAttempts: [String: Int] = [:]

    // MARK: - Discovered Server Model

    public struct DiscoveredServer: Identifiable {
        public let id = UUID()
        public let name: String
        public let endpoint: NWEndpoint
        public let isValidated: Bool // Whether IP passed validation checks

        public var url: URL? {
            switch endpoint {
            case .hostPort(let host, let port):
                let hostString: String
                switch host {
                case .ipv4(let address):
                    // Remove interface name (e.g., %en0) from IPv4 address
                    let addressStr = address.debugDescription
                    hostString = addressStr.components(separatedBy: "%").first ?? addressStr
                case .ipv6(let address):
                    // Keep zone ID (%en0) for link-local addresses - it's REQUIRED
                    // URL-encode the % as %25 for proper URL formatting
                    let addressStr = address.debugDescription
                    if addressStr.lowercased().hasPrefix("fe80:") {
                        // Link-local: keep zone ID and URL-encode %
                        let urlEncodedAddr = addressStr.replacingOccurrences(of: "%", with: "%25")
                        hostString = "[\(urlEncodedAddr)]"
                    } else {
                        // Non-link-local: remove zone ID if present
                        let cleanAddress = addressStr.components(separatedBy: "%").first ?? addressStr
                        hostString = "[\(cleanAddress)]"
                    }
                case .name(let hostname, _):
                    hostString = hostname
                @unknown default:
                    return nil
                }
                return URL(string: "ws://\(hostString):\(port)")
            default:
                return nil
            }
        }

        public var host: String? {
            switch endpoint {
            case .hostPort(let host, _):
                switch host {
                case .ipv4(let address):
                    let addressStr = address.debugDescription
                    return addressStr.components(separatedBy: "%").first ?? addressStr
                case .ipv6(let address):
                    let addressStr = address.debugDescription
                    return addressStr.components(separatedBy: "%").first ?? addressStr
                case .name(let hostname, _):
                    return hostname
                @unknown default:
                    return nil
                }
            default:
                return nil
            }
        }

        public var port: Int? {
            switch endpoint {
            case .hostPort(_, let port):
                return Int(port.rawValue)
            default:
                return nil
            }
        }
    }

    // MARK: - Initialization

    public init() {
        // Try to restore last known endpoint from UserDefaults
        if let host = UserDefaults.standard.string(forKey: "LastKnownHost"),
           let port = UserDefaults.standard.object(forKey: "LastKnownPort") as? Int {
            lastKnownEndpoint = (host, port)
            logger.info("[Bonjour] 📂 Restored cached endpoint: \(host):\(port)")
        }
    }

    // MARK: - Public API

    /// Start discovering Bonjour services on the local network
    public func startDiscovery() {
        guard !isSearching else {
            logger.warning("[Bonjour] ⚠️ Already searching for services")
            return
        }

        logger.info("[Bonjour] 🔍 Starting Bonjour service discovery for type: \(self.serviceType)")
        isSearching = true
        discoveryState = .discovering
        discoveredServers.removeAll()
        resolutionAttempts.removeAll()

        // Start fallback timer
        startFallbackTimer()

        // Create browser for specified service type
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)

        browser?.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch newState {
                case .ready:
                    self.logger.info("[Bonjour] ✅ Browser ready (service: \(self.serviceType))")
                case .failed(let error):
                    self.logger.error("[Bonjour] ❌ Browser failed: \(error.localizedDescription)")
                    self.handleDiscoveryFailure(error: error.localizedDescription)
                case .cancelled:
                    self.logger.info("[Bonjour] 🛑 Browser cancelled")
                    self.isSearching = false
                    if case .discovering = self.discoveryState {
                        self.discoveryState = .idle
                    }
                case .waiting(let error):
                    self.logger.warning("[Bonjour] ⏳ Browser waiting: \(error.localizedDescription)")
                default:
                    break
                }
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self.logger.info("[Bonjour] 📦 Browse results changed: \(changes.count) change(s)")

                for change in changes {
                    switch change {
                    case .added(let result):
                        self.handleServiceAdded(result)
                    case .removed(let result):
                        self.handleServiceRemoved(result)
                    case .changed(old: let oldResult, new: let newResult, flags: let flags):
                        self.logger.info("[Bonjour] 🔄 Service changed: \(oldResult.endpoint.debugDescription) -> \(newResult.endpoint.debugDescription), flags: \(flags.rawValue)")
                    @unknown default:
                        break
                    }
                }
            }
        }

        browser?.start(queue: .main)
    }

    /// Stop discovering services
    public func stopDiscovery() {
        logger.info("[Bonjour] 🛑 Stopping Bonjour service discovery")
        fallbackTimer?.cancel()
        fallbackTimer = nil
        browser?.cancel()
        browser = nil
        isSearching = false

        if case .discovering = discoveryState {
            discoveryState = .idle
        }
    }

    /// Manually trigger fallback to last known endpoint
    public func useFallbackEndpoint() {
        guard let endpoint = lastKnownEndpoint else {
            logger.warning("[Bonjour] ⚠️ No cached endpoint available for fallback")
            discoveryState = .failed(error: "No cached endpoint available")
            return
        }

        logger.info("[Bonjour] 🔄 Using fallback endpoint: \(endpoint.host):\(endpoint.port)")
        discoveryState = .fallbackUsingLastEndpoint(host: endpoint.host, port: endpoint.port)

        // Create a synthetic DiscoveredServer from cached endpoint
        if let host = IPv4Address(endpoint.host) {
            let syntheticEndpoint = NWEndpoint.hostPort(host: .ipv4(host), port: NWEndpoint.Port(rawValue: UInt16(endpoint.port))!)
            let server = DiscoveredServer(
                name: "Cached Server (Fallback)",
                endpoint: syntheticEndpoint,
                isValidated: false // Mark as not validated since it's from cache
            )
            discoveredServers.append(server)
        }
    }

    // MARK: - Private Methods

    private func startFallbackTimer() {
        fallbackTimer?.cancel()

        fallbackTimer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(self?.fallbackTimeout ?? 10.0 * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self = self else { return }

                if self.discoveredServers.isEmpty, case .discovering = self.discoveryState {
                    self.logger.warning("[Bonjour] ⏰ Fallback timer expired, no services found")
                    self.useFallbackEndpoint()
                }
            }
        }
    }

    private func handleServiceAdded(_ result: NWBrowser.Result) {
        logger.info("[Bonjour] 🎉 Service discovered: \(result.endpoint.debugDescription)")

        // Initialize retry counter for this service
        let serviceKey = result.endpoint.debugDescription
        resolutionAttempts[serviceKey] = 0

        // Resolve the service endpoint to get IP and port
        resolveService(result)
    }

    private func resolveService(_ result: NWBrowser.Result, retryCount: Int = 0) {
        let serviceKey = result.endpoint.debugDescription

        logger.info("[Bonjour] 🔍 Resolving service (attempt \(retryCount + 1)/\(self.maxRetryAttempts)): \(serviceKey)")

        // Create a temporary connection to resolve the endpoint
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        // Set up timeout
        let timeoutTask = Task { [weak self, weak connection] in
            try? await Task.sleep(nanoseconds: UInt64((self?.resolutionTimeout ?? 5.0) * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self, weak connection] in
                guard let self = self, let connection = connection else { return }

                if connection.state != .ready {
                    self.logger.warning("[Bonjour] ⏰ Resolution timeout for: \(serviceKey)")
                    connection.cancel()

                    // Retry if under max attempts
                    if retryCount < self.maxRetryAttempts - 1 {
                        self.logger.info("[Bonjour] 🔄 Retrying resolution (\(retryCount + 1)/\(self.maxRetryAttempts))...")
                        self.resolveService(result, retryCount: retryCount + 1)
                    } else {
                        self.logger.error("[Bonjour] ❌ Max retry attempts reached for: \(serviceKey)")
                    }
                }
            }
        }

        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch state {
                case .ready:
                    timeoutTask.cancel() // Cancel timeout since we succeeded

                    // Connection is ready - endpoint is now resolved
                    if let remoteEndpoint = connection.currentPath?.remoteEndpoint {
                        self.logger.info("[Bonjour] ✅ Service resolved to: \(remoteEndpoint.debugDescription)")

                        // Validate IP address
                        let (isValid, validationReason) = self.validateEndpoint(remoteEndpoint)

                        if isValid {
                            self.logger.info("[Bonjour] ✓ IP validation passed: \(validationReason)")

                            let server = DiscoveredServer(
                                name: result.endpoint.debugDescription,
                                endpoint: remoteEndpoint,
                                isValidated: true
                            )

                            if let url = server.url {
                                self.logger.info("[Bonjour]   URL: \(url.absoluteString)")
                                self.discoveredServers.append(server)

                                // Update last known endpoint
                                if let host = server.host, let port = server.port {
                                    self.lastKnownEndpoint = (host, port)
                                    self.discoveryState = .resolved(host: host, port: port)

                                    // Cancel fallback timer since we found a valid service
                                    self.fallbackTimer?.cancel()
                                }
                            } else {
                                self.logger.error("[Bonjour] ❌ Failed to create URL from resolved endpoint")
                            }
                        } else {
                            self.logger.warning("[Bonjour] ⚠️ IP validation failed: \(validationReason)")
                            self.logger.warning("[Bonjour]    Skipping endpoint: \(remoteEndpoint.debugDescription)")
                        }
                    }

                    // Cancel the connection - we only needed it for resolution
                    connection.cancel()

                case .failed(let error):
                    timeoutTask.cancel()
                    self.logger.error("[Bonjour] ❌ Failed to resolve service: \(error.localizedDescription)")
                    connection.cancel()

                    // Retry if under max attempts
                    if retryCount < self.maxRetryAttempts - 1 {
                        self.logger.info("[Bonjour] 🔄 Retrying resolution due to failure (\(retryCount + 1)/\(self.maxRetryAttempts))...")
                        Task {
                            // Small delay before retry
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            await MainActor.run {
                                self.resolveService(result, retryCount: retryCount + 1)
                            }
                        }
                    }

                case .waiting(let error):
                    self.logger.warning("[Bonjour] ⏳ Resolution waiting: \(error.localizedDescription)")

                default:
                    break
                }
            }
        }

        // Start the connection to trigger resolution
        connection.start(queue: .main)
    }

    /// Validates an endpoint to filter out proxy IPs, loopback, and link-local addresses
    /// Returns: (isValid, reason)
    private func validateEndpoint(_ endpoint: NWEndpoint) -> (Bool, String) {
        guard case .hostPort(let host, _) = endpoint else {
            return (false, "Not a host:port endpoint")
        }

        switch host {
        case .ipv4(let address):
            let addressStr = address.debugDescription.components(separatedBy: "%").first ?? address.debugDescription
            return validateIPv4Address(addressStr)

        case .ipv6(let address):
            let addressStr = address.debugDescription.components(separatedBy: "%").first ?? address.debugDescription
            return validateIPv6Address(addressStr)

        case .name(let hostname, _):
            // Hostname-based endpoints are generally acceptable
            return (true, "Hostname: \(hostname)")

        @unknown default:
            return (false, "Unknown host type")
        }
    }

    /// Validates IPv4 addresses, filtering out problematic IPs
    private func validateIPv4Address(_ address: String) -> (Bool, String) {
        let components = address.components(separatedBy: ".")
        guard components.count == 4,
              let first = Int(components[0]),
              let second = Int(components[1]) else {
            return (false, "Invalid IPv4 format")
        }

        // Filter loopback (127.0.0.0/8)
        if first == 127 {
            return (false, "Loopback address (127.x.x.x)")
        }

        // Filter link-local (169.254.0.0/16)
        if first == 169 && second == 254 {
            return (false, "Link-local address (169.254.x.x)")
        }

        // Filter common DNS proxy IPs used by carriers
        // KT and other carriers often use 192.0.0.x range for DNS proxy/NAT
        if first == 192 && second == 0 && Int(components[2]) == 0 {
            return (false, "DNS proxy address (192.0.0.x) - likely KT NAT/proxy")
        }

        // Filter 0.0.0.0
        if address == "0.0.0.0" {
            return (false, "Null address (0.0.0.0)")
        }

        // Filter broadcast (255.255.255.255)
        if address == "255.255.255.255" {
            return (false, "Broadcast address")
        }

        // Accept private network ranges
        // 10.0.0.0/8
        if first == 10 {
            return (true, "Private network (10.x.x.x)")
        }

        // 172.16.0.0/12
        if first == 172 && (second >= 16 && second <= 31) {
            return (true, "Private network (172.16-31.x.x)")
        }

        // 192.168.0.0/16
        if first == 192 && second == 168 {
            return (true, "Private network (192.168.x.x)")
        }

        // Accept other IPs (public IPs, though less common in local discovery)
        return (true, "Valid IP: \(address)")
    }

    /// Validates IPv6 addresses
    private func validateIPv6Address(_ address: String) -> (Bool, String) {
        let lowercased = address.lowercased()

        // Filter loopback (::1)
        if lowercased == "::1" || lowercased == "0:0:0:0:0:0:0:1" {
            return (false, "IPv6 loopback (::1)")
        }

        // ALLOW link-local (fe80::/10) for hotspot environments
        // Link-local addresses are VALID for devices on the same network segment
        // This is critical for KT hotspot IPv6-only networks
        if lowercased.hasPrefix("fe80:") {
            return (true, "IPv6 link-local (fe80::) - valid for local network")
        }

        // Filter null address (::)
        if lowercased == "::" || lowercased == "0:0:0:0:0:0:0:0" {
            return (false, "IPv6 null address (::)")
        }

        // Accept unique local addresses (fc00::/7) - similar to IPv4 private ranges
        if lowercased.hasPrefix("fc") || lowercased.hasPrefix("fd") {
            return (true, "IPv6 unique local address")
        }

        // Accept other IPv6 addresses (global unicast, etc.)
        return (true, "Valid IPv6: \(address)")
    }

    private func handleServiceRemoved(_ result: NWBrowser.Result) {
        logger.info("[Bonjour] 👋 Service removed: \(result.endpoint.debugDescription)")

        let beforeCount = discoveredServers.count
        discoveredServers.removeAll { server in
            server.endpoint.debugDescription == result.endpoint.debugDescription
        }
        let afterCount = discoveredServers.count

        if beforeCount != afterCount {
            logger.info("[Bonjour] 🗑️ Removed server from list (count: \(beforeCount) → \(afterCount))")
        }
    }

    private func handleDiscoveryFailure(error: String) {
        logger.error("[Bonjour] ❌ Discovery failed: \(error)")
        isSearching = false

        // Try fallback if available
        if lastKnownEndpoint != nil {
            logger.info("[Bonjour] 🔄 Attempting fallback to last known endpoint...")
            useFallbackEndpoint()
        } else {
            discoveryState = .failed(error: error)
        }
    }

    // MARK: - Deinitialization

    nonisolated deinit {
        Task { @MainActor [weak self] in
            self?.stopDiscovery()
        }
    }
}

// MARK: - Extensions

extension BonjourServiceDiscovery {
    /// Manually add a known endpoint (useful for testing or manual configuration)
    public func addManualEndpoint(host: String, port: Int) {
        logger.info("[Bonjour] ➕ Adding manual endpoint: \(host):\(port)")

        if let ipv4 = IPv4Address(host) {
            let endpoint = NWEndpoint.hostPort(host: .ipv4(ipv4), port: NWEndpoint.Port(rawValue: UInt16(port))!)
            let server = DiscoveredServer(
                name: "Manual Entry",
                endpoint: endpoint,
                isValidated: false
            )
            discoveredServers.append(server)
            lastKnownEndpoint = (host, port)
            discoveryState = .resolved(host: host, port: port)
        } else {
            logger.error("[Bonjour] ❌ Invalid IPv4 address: \(host)")
        }
    }

    /// Clear cached endpoint
    public func clearCache() {
        logger.info("[Bonjour] 🗑️ Clearing cached endpoint")
        lastKnownEndpoint = nil
        UserDefaults.standard.removeObject(forKey: "LastKnownHost")
        UserDefaults.standard.removeObject(forKey: "LastKnownPort")
    }
}
