//
//  FileDemoFrameSource.swift
//  Hippo
//
//  File-based frame source for Demo mode
//  Uses SerialProcessor to read SBS video files and emit CMSampleBuffers
//

import Foundation
import AVFoundation
import os.log

/// 파일 기반 Demo 모드용 프레임 소스
/// SerialProcessor를 사용하여 로컬 SBS 비디오 파일을 읽고 CMSampleBuffer로 전달
@MainActor
final class FileDemoFrameSource: EndoscopeFrameSource {

    // MARK: - EndoscopeFrameSource Protocol

    var onFrame: ((CMSampleBuffer) -> Void)?

    // MARK: - Private Properties

    private let fileURL: URL
    private var serialProcessor: SerialProcessor?
    private var isPlaying = false
    private let logger = Logger(subsystem: "com.television.hippo", category: "FileDemoFrameSource")

    /// Renderer 준비 상태 체크 클로저 (back-pressure 제어용)
    public var isRendererReady: (() -> Bool)?

    /// 루프 재생 여부 (기본값: true - 데모용이므로 무한 반복)
    public var shouldLoop: Bool = true

    // MARK: - Initialization

    init(url: URL) {
        self.fileURL = url
        logger.info("FileDemoFrameSource initialized with URL: \(url.lastPathComponent)")
    }

    deinit {
        logger.info("FileDemoFrameSource deallocated")
    }

    // MARK: - Public Methods

    func start() async throws {
        guard !isPlaying else {
            logger.warning("FileDemoFrameSource already playing")
            return
        }

        logger.info("🎬 Starting file playback: \(self.fileURL.lastPathComponent)")
        isPlaying = true

        logger.info("⏳ Waiting 150ms for VideoPlayer initialization...")
        try await Task.sleep(nanoseconds: 150_000_000)  // 0.15 seconds

        var loopCount = 0
        repeat {
            loopCount += 1
            if loopCount > 1 {
                logger.info("🔄 Loop #\(loopCount) - restarting playback")
                try await Task.sleep(nanoseconds: 50_000_000)  // 50ms 자연스러운 전환
            }
            try await playOnce()
        } while shouldLoop && isPlaying

        logger.info("✅ File playback ended (loops: \(loopCount))")
    }

    // MARK: - Private Methods

    /// 파일을 한 번 재생
    private func playOnce() async throws {
        let processor = SerialProcessor(
            assetURL: fileURL,
            stereoMetadata: .default,
            frameHandler: { [weak self] sampleBuffer in
                guard let self else { return }
                Task { @MainActor in self.onFrame?(sampleBuffer) }
            },
            isRendererReady: isRendererReady
        )
        self.serialProcessor = processor
        try await processor.process()
    }

    func stop() {
        guard isPlaying else {
            logger.warning("FileDemoFrameSource not playing")
            return
        }

        logger.info("🛑 Stopping file playback")
        isPlaying = false
        serialProcessor?.cancel()
        serialProcessor = nil
        logger.info("✅ File playback stopped")
    }
}
