//
//  EndoscopeStreamViewModel.swift
//  Hippo
//
//  ViewModel for endoscope streaming
//  Handles Bonjour service discovery and WebRTC connection lifecycle
//

import Foundation
import os.log
import Combine

@MainActor
final class EndoscopeStreamViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var connectionStatus: ConnectionStatus = .idle
    @Published var webRTCReceiver: WebRTCReceiver
    @Published var settings = ConnectionSettings()

    // MARK: - Private Properties

    private let bonjourDiscovery = BonjourServiceDiscovery()
    private let logger = Logger(subsystem: "com.television.hippo", category: "EndoscopeStreamViewModel")
    private let renderPipeline: EndoscopeRenderPipeline

    // MARK: - Connection Status

    enum ConnectionStatus: Equatable {
        case idle
        case discovering
        case connecting
        case connected
        case failed(String)

        var isActive: Bool {
            switch self {
            case .connected, .connecting:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Create pipeline in @MainActor context (no actor isolation issues)
        self.renderPipeline = EndoscopeRenderPipeline()

        // Inject pipeline into receiver (DI pattern)
        self.webRTCReceiver = WebRTCReceiver(renderPipeline: self.renderPipeline)
    }

    // MARK: - Public Methods

    /// Start Bonjour discovery and connect to server
    func connect() async {
        logger.info("🚀 Starting connection process...")

        // Check if manual connection is enabled
        if settings.useManualConnection {
            await connectManually()
            return
        }

        // For simulator: use localhost by default
        #if targetEnvironment(simulator)
        logger.info("🖥️ Running on simulator - using localhost")
        let localhostURL = URL(string: "ws://127.0.0.1:8080")!
        await connectToServer(url: localhostURL)
        #else
        // Step 1: Discover server via Bonjour (real device only)
        guard let serverURL = await discoverServer() else {
            return // Status already updated in discoverServer()
        }

        // Step 2: Connect to discovered server
        await connectToServer(url: serverURL)
        #endif
    }

    /// Connect to server using manually configured IP address
    func connectManually() async {
        logger.info("🔧 Using manual connection...")

        guard let serverURL = settings.serverURL else {
            logger.error("❌ Invalid server URL")
            logger.info("💡 Falling back to Bonjour auto-discovery...")

            // Disable manual connection and retry with auto-discovery
            settings.useManualConnection = false
            await connect()
            return
        }

        logger.info("📍 Manual server URL: \(serverURL.absoluteString)")
        await connectToServer(url: serverURL)

        // If connection failed and we're on a hotspot, suggest disabling manual mode
        if case .failed = connectionStatus {
            logger.warning("⚠️ Manual connection failed. This may be due to:")
            logger.warning("   - KT hotspot using IPv6-only networking")
            logger.warning("   - Old IP address from different session")
            logger.warning("💡 Try disabling manual connection to use auto-discovery")
        }
    }

    /// Disconnect from server and cleanup
    func disconnect() async {
        logger.info("🛑 Disconnecting...")

        bonjourDiscovery.stopDiscovery()
        await webRTCReceiver.stop()

        connectionStatus = .idle
        logger.info("✅ Disconnected")
    }

    // MARK: - Private Methods

    /// Discover WebRTC signaling server via Bonjour
    private func discoverServer() async -> URL? {
        logger.info("🔍 Starting Bonjour service discovery...")
        connectionStatus = .discovering

        bonjourDiscovery.startDiscovery()

        // Wait for server discovery with timeout
        let timeout: TimeInterval = 20.0
        let startTime = Date()

        while bonjourDiscovery.discoveredServers.isEmpty {
            // Check timeout
            if Date().timeIntervalSince(startTime) > timeout {
                logger.error("❌ Server discovery timeout")
                connectionStatus = .failed("서버를 찾을 수 없습니다.\nMac에서 서버가 실행 중인지 확인하세요.")
                bonjourDiscovery.stopDiscovery()
                return nil
            }

            // Sleep for 100ms
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Get first discovered server
        guard let server = bonjourDiscovery.discoveredServers.first,
              let serverURL = server.url else {
            logger.error("❌ Failed to get server URL")
            connectionStatus = .failed("서버 URL을 가져올 수 없습니다.")
            bonjourDiscovery.stopDiscovery()
            return nil
        }

        logger.info("✅ Server discovered: \(serverURL.absoluteString)")
        bonjourDiscovery.stopDiscovery()

        return serverURL
    }

    /// Connect to WebRTC signaling server
    private func connectToServer(url: URL) async {
        logger.info("🔌 Connecting to server: \(url.absoluteString)")
        connectionStatus = .connecting

        do {
            try await webRTCReceiver.updateSignalingServer(url: url)
            connectionStatus = .connected
            logger.info("✅ Connected successfully")
        } catch {
            logger.error("❌ Connection failed: \(error.localizedDescription)")
            connectionStatus = .failed("연결 실패: \(error.localizedDescription)")
        }
    }
}
