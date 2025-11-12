//
//  AppModule.swift
//  Hippo
//
//  Main pipeline orchestration module
//  Coordinates: Capture → FrameSync → Composer → WebRTC
//  Enhanced with P0.2: Actor-based configuration management
//

import Foundation
import CoreVideo
import CoreMedia
import os.log
import AVFoundation
import Combine

// MARK: - Sendable Wrapper

/// Thread-safe wrapper for CVPixelBuffer
fileprivate struct SendablePixelBuffer: @unchecked Sendable {
    nonisolated(unsafe) let pixelBuffer: CVPixelBuffer

    nonisolated init(_ pixelBuffer: CVPixelBuffer) {
        self.pixelBuffer = pixelBuffer
    }
}

// MARK: - AppModule

@MainActor
public final class AppModule: ObservableObject {

    // MARK: Published Properties

    @Published public var isStreaming: Bool = false
    @Published public var currentSBSMode: SBSMode = .full1080 {
        didSet {
            Task {
                await configManager.setSBSMode(currentSBSMode)
            }
        }
    }
    @Published public var previewPixelBuffer: CVPixelBuffer?
    @Published public var stats: String = ""

    // MARK: Components

    private var leftCapture: LeftCaptureSession?
    private var rightCapture: RightCaptureSession?
    private var frameSync: FrameSync?
    private var composer: CI_SBSComposer?
    private var transport: WebRTCManager?

    // P0.2: Actor-based configuration
    private let configManager = PipelineConfigurationManager()

    // MARK: Queues

    private let processingQueue: DispatchQueue

    // MARK: Logging

    private let logger = Logger(subsystem: "com.television.hippo", category: "AppModule")

    // MARK: Initialization

    public init() {
        self.processingQueue = DispatchQueue(
            label: "com.television.hippo.processing",
            qos: .userInteractive
        )
    }

    // MARK: - Public Methods

    public func start() async throws {
        logger.info("🚀 Starting streaming pipeline...")

        // 1. Request camera permission
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            throw VideoError.cameraPermissionDenied
        }

        // 2. Initialize components
        frameSync = FrameSync()
        composer = CI_SBSComposer()
        transport = WebRTCManager(config: .standard)

        leftCapture = LeftCaptureSession()
        rightCapture = RightCaptureSession()

        // 3. Setup frame sync callback
        frameSync?.onPair = { [weak self] pair in
            self?.handleSyncedPair(pair)
        }

        // 4. Set capture delegates
        leftCapture?.delegate = self
        rightCapture?.delegate = self

        // 5. Start transport
        try transport?.start()

        // 6. Start capture sessions
        try leftCapture?.start()
        try rightCapture?.start()

        isStreaming = true
        logger.info("✅ Streaming pipeline started")
    }

    public func stop() {
        logger.info("🛑 Stopping streaming pipeline...")

        leftCapture?.stop()
        rightCapture?.stop()

        // Reset FrameSync buffers before stopping
        frameSync?.reset()

        transport?.stop()

        leftCapture = nil
        rightCapture = nil
        frameSync = nil
        composer = nil
        transport = nil

        isStreaming = false
        logger.info("✅ Streaming pipeline stopped")
    }

    // MARK: - Private Methods

    private func handleSyncedPair(_ pair: SyncedPair) {
        Task { [weak self] in
            guard let self = self else { return }

            // P0.2: Get configuration atomically
            let config = await self.configManager.makeComposerConfig()

            // Get MainActor properties once
            let (composer, transport) = await MainActor.run {
                (self.composer, self.transport)
            }

            do {
                // Compose SBS frame (CPU-intensive, off MainActor)
                let composed = try composer?.compose(
                    left: pair.left,
                    right: pair.right,
                    leftSize: pair.leftSize,
                    rightSize: pair.rightSize,
                    config: config
                )

                guard let composed = composed else {
                    return
                }

                // Send via WebRTC
                transport?.send(pixelBuffer: composed, presentationTime: pair.pts)

                // Update preview (MainActor)
                Task { @MainActor [weak self] in
                    self?.updatePreview(composed)
                }

            } catch {
                Task { @MainActor [weak self] in
                    self?.logger.error("❌ Composition failed: \(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    private func updatePreview(_ pixelBuffer: CVPixelBuffer) {
        self.previewPixelBuffer = pixelBuffer
    }
}

// MARK: - CaptureOutputDelegate

extension AppModule: CaptureOutputDelegate {

    nonisolated public func didOutput(pixelBuffer: CVPixelBuffer, pts: CMTime, source: CaptureSource) {
        // Wrap CVPixelBuffer to safely cross actor boundary
        let sendableBuffer = SendablePixelBuffer(pixelBuffer)
        Task { @MainActor [weak self] in
            self?.frameSync?.push(sendableBuffer.pixelBuffer, pts: pts, source: source)
        }
    }

    nonisolated public func didEncounterError(_ error: Error, source: CaptureSource) {
        Task { @MainActor in
            logger.error("❌ Capture error [\(source.rawValue)]: \(error.localizedDescription)")
        }
    }
}
