//
//  StreamUIState.swift
//  Hippo
//
//  UI state management for endoscope stream view mode transitions
//  Ensures pipeline preparation completes before view switching
//

import Foundation
import SwiftUI
import os.log
import Combine

// MARK: - Demo Display Mode

/// Demo 모드 내에서의 표시 방식
/// UI 라벨: Standard (2D) / 3D / Image
enum DemoDisplayMode: String, CaseIterable {
    case standard   // 내부적으로 2D (fileDemo2D)
    case stereo3D   // 내부적으로 3D (fileDemo)
    case image      // 내부적으로 Image (fileImage)

    /// UI 표시용 라벨 (2D 대신 Standard 사용)
    var displayLabel: String {
        switch self {
        case .standard: return "Standard"
        case .stereo3D: return "3D"
        case .image: return "Image"
        }
    }

    /// 아이콘
    var icon: String {
        switch self {
        case .standard: return "rectangle.on.rectangle"
        case .stereo3D: return "cube.fill"
        case .image: return "photo.fill"
        }
    }

    /// EndoscopeViewMode로 변환
    var viewMode: EndoscopeViewMode {
        switch self {
        case .standard: return .fileDemo2D
        case .stereo3D: return .fileDemo
        case .image: return .fileImage
        }
    }

    /// EndoscopeViewMode에서 생성
    init(from viewMode: EndoscopeViewMode) {
        switch viewMode {
        case .fileDemo2D: self = .standard
        case .fileDemo: self = .stereo3D
        case .fileImage: self = .image
        default: self = .stereo3D  // 기본값
        }
    }
}

/// Manages UI state for stream view mode transitions
/// Coordinates timing between pipeline preparation and view rendering
@MainActor
final class StreamUIState: ObservableObject {

    // MARK: - Published Properties

    /// Currently active (fully prepared and visible) mode
    /// Default: fileDemo (3D demo for initial showcase)
    @Published var activeMode: EndoscopeViewMode = .fileDemo

    /// Demo 모드 내에서의 표시 방식 (Standard/3D)
    /// activeMode가 Demo일 때만 유효
    @Published var demoDisplayMode: DemoDisplayMode = .stereo3D

    /// Whether a mode transition is in progress
    @Published var isSwitching: Bool = false

    /// 3D Demo 모드에서 현재 재생 중인 영상 소스
    /// 기본값: Demo3DDefaults.initialSource (bird)
    @Published var demo3DSource: Demo3DVideoSource = Demo3DDefaults.initialSource

    // MARK: - Computed Properties

    /// Live 모드인지 (WebRTC)
    var isLiveMode: Bool { activeMode.isWebRTCMode }

    /// Demo 모드인지 (Standard 또는 3D)
    var isDemoMode: Bool { activeMode.isDemoMode }

    // MARK: - Callbacks

    /// Called when exiting Demo mode (for cleanup)
    public var onExitDemoMode: (() -> Void)?

    // MARK: - Private Properties

    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "StreamUIState"
    )

    // MARK: - Initialization

    init(initialMode: EndoscopeViewMode = .fileDemo) {
        self.activeMode = initialMode
        self.demo3DSource = Demo3DDefaults.initialSource
        logger.info("StreamUIState initialized with mode: \(initialMode.rawValue), demo3DSource: \(Demo3DDefaults.initialSource.rawValue)")
    }

    // MARK: - Demo 3D Source Management

    /// 3D Demo 소스를 기본값으로 리셋
    func resetDemo3DSource() {
        demo3DSource = Demo3DDefaults.initialSource
        logger.info("Demo3DSource reset to default: \(Demo3DDefaults.initialSource.rawValue)")
    }

    // MARK: - Public Methods

    /// Switch to a new mode with proper pipeline preparation
    /// - Parameters:
    ///   - newMode: Target mode to switch to
    ///   - pipeline: Pipeline to configure
    /// - Note: Ensures pipeline is fully prepared before updating activeMode
    func switchMode(
        to newMode: EndoscopeViewMode,
        pipeline: EndoscopeRenderPipeline
    ) async {
        // Skip if already in target mode
        guard activeMode != newMode else {
            logger.info("Already in mode: \(newMode.rawValue)")
            return
        }

        logger.info("🔄 Mode switch requested: \(self.activeMode.rawValue) → \(newMode.rawValue)")

        // Cleanup Demo mode resources if exiting from Demo
        if activeMode.isDemoMode && !newMode.isDemoMode {
            logger.info("   Exiting Demo mode - triggering cleanup...")
            onExitDemoMode?()
        }

        // CRITICAL: Demo modes are now handled by PrimaryModeToggle
        // Demo 진입: PrimaryModeToggle → stopAll() → configure(.fileDemo/.fileDemo2D) → update UI
        // This ensures proper initialization for file-based modes
        if newMode.isDemoMode {
            logger.info("⚠️ switchMode() called for Demo mode: \(newMode.rawValue)")
            logger.info("   Note: Demo configuration should be handled by PrimaryModeToggle")
            logger.info("   Updating UI state only")
            isSwitching = true
            activeMode = newMode
            try? await Task.sleep(for: .milliseconds(50))
            isSwitching = false
            logger.info("✅ Mode switch complete (UI updated to \(newMode.rawValue))")
            return
        }

        // Step 1: Mark as switching (shows overlay) and pause frame processing
        isSwitching = true
        pipeline.beginModeChange()  // Blocks all frame enqueues

        // Step 2: Wait for pipeline to prepare
        logger.info("   Step 1/4: Preparing pipeline...")
        await preparePipeline(for: newMode, pipeline: pipeline)

        // Step 3: Extended delay to ensure VideoPlayer is fully initialized
        // This prevents 0x0 frame and backpressure errors
        // Increased from 100ms to 250ms based on observed renderer ready timing
        logger.info("   Step 2/3: Waiting for pipeline stabilization...")
        try? await Task.sleep(for: .milliseconds(250))

        // Step 4: Update active mode (triggers view switch)
        logger.info("   Step 3/4: Updating UI to \(newMode.rawValue)")
        activeMode = newMode

        // Step 5: Critical delay for VideoPlayerComponent to be added to RealityView
        // Without this, frames will be enqueued before renderer is connected → CRASH
        // RealityView attachment happens asynchronously after view appears
        logger.info("   Step 4/5: Waiting for VideoPlayerComponent attachment...")
        try? await Task.sleep(for: .milliseconds(200))  // Increased from 150ms to 200ms

        // Step 6: Resume frame processing FIRST (before clearing overlay)
        pipeline.completeModeChange()  // Unblocks frame enqueues

        // Step 7: Small delay for first frames to process
        try? await Task.sleep(for: .milliseconds(50))

        // Step 8: Clear switching state (hides overlay)
        isSwitching = false

        logger.info("✅ Mode switch complete: \(newMode.rawValue)")
    }

    // MARK: - Private Helpers

    /// Prepare pipeline for new mode (async to avoid blocking UI)
    private func preparePipeline(
        for mode: EndoscopeViewMode,
        pipeline: EndoscopeRenderPipeline
    ) async {
        // Configure pipeline (this recreates VideoPlayer, etc.)
        pipeline.configure(for: mode)

        logger.info("   ✓ Pipeline configured for: \(mode.rawValue)")
    }
}
