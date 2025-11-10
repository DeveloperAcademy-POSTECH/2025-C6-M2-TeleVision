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

    // MARK: - Private Properties

    private let bonjourDiscovery = BonjourServiceDiscovery()
    private let logger = Logger(subsystem: "com.television.hippo", category: "EndoscopeStreamViewModel")

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
        self.webRTCReceiver = WebRTCReceiver()
    }

    // MARK: - Public Methods

    /// Start Bonjour discovery and connect to server
    func connect() async {
        logger.info("🚀 Starting connection process...")

        // Step 1: Discover server via Bonjour
        guard let serverURL = await discoverServer() else {
            return // Status already updated in discoverServer()
        }

        // Step 2: Connect to discovered server
        await connectToServer(url: serverURL)
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
