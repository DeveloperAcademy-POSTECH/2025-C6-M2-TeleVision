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
    @Published var activeMode: EndoscopeViewMode? = nil  // nil = not configured yet (prevents "Already in mode" bugs)

    // MARK: - Private Properties

    private let bonjourDiscovery = BonjourServiceDiscovery()
    private let logger = Logger(subsystem: "com.television.hippo", category: "EndoscopeStreamViewModel")
    private let renderPipeline: EndoscopeRenderPipeline
    private var fileDemoSource: FileDemoFrameSource?  // 파일 데모 소스

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

        // NOTE: Pipeline configuration will be done in .task block
        // This allows configure() to run fully without early return
        self.logger.info("✅ ViewModel initialized (pipeline configuration deferred)")
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

    // MARK: - Mode Configuration

    /// Endoscope 모드 구성 (WebRTC vs File)
    /// - Parameter mode: 대상 모드
    func configure(for mode: EndoscopeViewMode) async {
        // CRITICAL FIX: Don't skip if resources might be missing
        // activeMode tracks intent, but actual resources (VideoPlayer/FileDemoSource) might be nil
        // after cleanup/disconnect, so always reconfigure to ensure resources exist
        if let currentMode = activeMode, currentMode == mode {
            logger.info("Already in mode: \(mode.rawValue), but reconfiguring to ensure resources exist")
        } else {
            logger.info("🔄 Configuring Endoscope for mode: \(mode.rawValue)")
        }

        activeMode = mode

        if mode.requiresWebRTC {
            // ✅ WebRTC 기반 모드 (Raw / Split / 3D)
            logger.info("   Mode requires WebRTC - cleaning up file source")

            // 파일 소스 정리
            fileDemoSource?.stop()
            fileDemoSource = nil

            // 파이프라인 모드 설정
            renderPipeline.configure(for: mode)

            // WebRTC 연결은 기존 connect() 메서드 사용
            // (여기서는 모드만 설정, 실제 연결은 외부에서 호출)
            logger.info("   Pipeline configured for WebRTC mode: \(mode.rawValue)")

        } else {
            // ✅ 파일 기반 Demo 모드
            logger.info("   Mode is file-based Demo - setting up file source")

            // WebRTC 완전히 정리
            await disconnect()

            // 번들에서 endoscope-demo.mp4 로드
            guard let url = Bundle.main.url(forResource: "endoscope-demo", withExtension: "mp4") else {
                logger.error("❌ endoscope-demo.mp4 not found in bundle")
                logger.error("   Make sure endoscope-demo.mp4 is added to the project with target membership")
                return
            }

            logger.info("   Found endoscope-demo.mp4 at: \(url.lastPathComponent)")

            // FileDemoFrameSource 생성
            let source = FileDemoFrameSource(url: url)
            self.fileDemoSource = source

            // 프레임 콜백 연결: FileDemoSource → RenderPipeline
            source.onFrame = { [weak self] sampleBuffer in
                guard let self else { return }
                Task { @MainActor in
                    await self.renderPipeline.enqueue(sampleBuffer: sampleBuffer)
                }
            }

            // Back-pressure 제어: Renderer 준비 상태 체크
            source.isRendererReady = { [weak self] in
                guard let self else { return false }
                return self.renderPipeline.isRendererReady()
            }

            // Demo 모드는 .fileDemo 모드 사용 (옵션 A)
            logger.info("   Configuring pipeline for fileDemo mode")
            renderPipeline.configure(for: .fileDemo)

            // 파일 재생 시작 (background Task - configure가 바로 완료되도록)
            Task { @MainActor in
                do {
                    try await source.start()
                    self.logger.info("✅ Demo mode playback ended")
                } catch {
                    self.logger.error("❌ Failed to start file playback: \(error.localizedDescription)")
                }
            }
            logger.info("✅ Demo mode activated - playing endoscope-demo.mp4")
        }
    }

    /// 모든 소스 정리 (화면 종료 시)
    func stopAll() {
        logger.info("Stopping all sources")

        // 파일 소스 정리
        fileDemoSource?.stop()
        fileDemoSource = nil

        // CRITICAL FIX: Reset mode state to nil to force reconfiguration
        // This prevents "Already in mode" bug when switching back to same mode
        // (e.g., Demo → WebRTC → Demo would skip Demo setup if activeMode stayed .fileDemo)
        activeMode = nil
        logger.info("   Mode state reset to nil (forces reconfiguration on next mode switch)")

        // WebRTC 정리
        Task {
            await disconnect()
        }
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
