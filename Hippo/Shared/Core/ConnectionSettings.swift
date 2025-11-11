//
//  ConnectionSettings.swift
//  Hippo
//
//  Settings for manual server connection
//

import Foundation
import Combine
import os.log

@MainActor
final class ConnectionSettings: ObservableObject {

    // MARK: - Published Properties

    @Published var useManualConnection: Bool {
        didSet {
            UserDefaults.standard.set(useManualConnection, forKey: "UseManualConnection")
            logger.info("🔧 useManualConnection updated: \(self.useManualConnection)")
        }
    }

    @Published var serverIP: String {
        didSet {
            UserDefaults.standard.set(serverIP, forKey: "ServerIP")
            logger.info("🔧 serverIP updateself.d: \(self.serverIP)")
        }
    }

    @Published var serverPort: String {
        didSet {
            UserDefaults.standard.set(serverPort, forKey: "ServerPort")
            logger.info("🔧 serverPort uself.pdateself.self.d: \(self.serverPort)")
        }
    }

    @Published var isDetecting: Bool = false
    @Published var detectionStatus: String = ""

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.television.hippo", category: "ConnectionSettings")
    private var bonjourDiscovery: BonjourServiceDiscovery?

    // MARK: - Computed Properties

    var serverURL: URL? {
        guard !serverIP.isEmpty else { return nil }
        let port = serverPort.isEmpty ? "8080" : serverPort
        return URL(string: "ws://\(serverIP):\(port)")
    }

    // MARK: - Initialization

    init() {
        self.useManualConnection = UserDefaults.standard.bool(forKey: "UseManualConnection")
        self.serverIP = UserDefaults.standard.string(forKey: "ServerIP") ?? ""
        self.serverPort = UserDefaults.standard.string(forKey: "ServerPort") ?? "8080"

        logger.info("📂 Loaded settings - Manual: \(self.useManualConnection), IP: \(self.serverIP), Port: \(self.serverPort)")

        // Auto-disable manual connection if saved IP looks invalid or from different network
        // This helps with KT hotspot IPv6-only networks where old IPv4 addresses won't work
        if self.useManualConnection && !self.serverIP.isEmpty {
            // Check if IP starts with common problematic patterns
            if self.serverIP.starts(with: "192.168") ||
               self.serverIP.starts(with: "10.") ||
               self.serverIP.starts(with: "172.") {
                logger.warning("⚠️ Saved IP may be from different network session. Consider using auto-discovery instead.")
                logger.warning("💡 Tip: Disable manual connection to use Bonjour auto-discovery")
            }
        }
    }

    // MARK: - Methods

    func reset() {
        useManualConnection = false
        serverIP = ""
        serverPort = "8080"
        logger.info("🔄 Settings reset")
    }

    /// Auto-detect server IP using Bonjour
    func autoDetectServer() async {
        logger.info("🔍 Starting auto-detection...")

        isDetecting = true
        detectionStatus = "서버 검색 중..."

        // Create new Bonjour discovery instance
        let discovery = BonjourServiceDiscovery()
        self.bonjourDiscovery = discovery

        // Start discovery
        discovery.startDiscovery()

        // Wait up to 10 seconds for discovery
        let timeout: TimeInterval = 10.0
        let startTime = Date()

        while discovery.discoveredServers.isEmpty {
            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                logger.warning("⏰ Auto-detection timeout")
                detectionStatus = "서버를 찾을 수 없습니다"
                isDetecting = false
                discovery.stopDiscovery()
                return
            }

            // Sleep for 100ms
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Server found!
        if let server = discovery.discoveredServers.first,
           let host = server.host,
           let port = server.port {

            logger.info("✅ Server auto-detected: \(host):\(port)")

            // Update settings
            serverIP = host
            serverPort = String(port)
            detectionStatus = "서버 발견: \(host)"

            // Small delay to show success message
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        } else {
            logger.error("❌ Failed to extract server info")
            detectionStatus = "서버 정보를 가져올 수 없습니다"
        }

        isDetecting = false
        discovery.stopDiscovery()
    }
}
