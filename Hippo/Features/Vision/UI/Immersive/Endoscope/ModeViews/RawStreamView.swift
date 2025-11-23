//
//  RawStreamView.swift
//  Hippo
//
//  Stage 1: Raw SBS view (safest fallback)
//  Displays raw SBS frame directly without processing
//

import SwiftUI
import RealityKit
import AVFoundation
import os.log

/// Stage 1: Raw Stream View (Safest Fallback)
/// Displays raw SBS video stream as-is (3840×1080 or 1920×540)
struct RawStreamView: View {
    // Only observe receiver (pipeline is accessed via receiver)
    @ObservedObject var receiver: WebRTCReceiver

    // Pipeline reference (no observation needed, just access)
    let pipeline: EndoscopeRenderPipeline

    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "RawStreamView"
    )

    // Constants for stable positioning (same as Stereo3DView)
    private static let entityName = "raw-video-entity"
    private static let entityPosition = SIMD3<Float>.zero  // 1.5m in front
    private static let entityScale = SIMD3<Float>(0.2, 0.2, 0.2)  // Much smaller to see full frame

    // MARK: - Body

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            logSetup()

            // Create entity with VideoPlayerComponent
            let entity = makeVideoPlayerEntity()
            content.add(entity)

            logEntityCreated(entity)

        } update: { content in
            // Position and scale are fixed for stability
        }
        .frame(depth: 0)
        .onAppear {
            logger.info("RawStreamView appeared")
            logger.info("   Current mode: \(receiver.currentViewMode.rawValue)")
        }
        .onDisappear {
            logger.info("RawStreamView disappeared")
        }
        #else
        Color.black
            .overlay(
                Text("Raw stream view requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }

    // MARK: - Setup Helpers

    /// Log renderer status at setup
    private func logSetup() {
        logger.info("RawStreamView: Creating RealityView")

        if let videoPlayer = pipeline.getVideoRenderer() {
            let renderer = videoPlayer.videoRenderer
            logger.info("   VideoPlayer available: YES")
            logger.info("   Renderer status: \(renderer.status.rawValue)")
        } else {
            logger.error("   VideoPlayer available: NO")
        }

        logger.info("   Current frame size: \(Int(receiver.currentFrameSize.width))×\(Int(receiver.currentFrameSize.height))")
    }

    /// Create VideoPlayerComponent entity with stable position and scale
    private func makeVideoPlayerEntity() -> Entity {
        guard let videoPlayer = pipeline.getVideoRenderer() else {
            logger.error("CRITICAL: VideoPlayer not found in pipeline!")

            let entity = Entity()
            entity.name = Self.entityName
            return entity
        }

        logger.info("Creating VideoPlayerComponent")

        // Create VideoPlayerComponent
        let videoPlayerComponent = VideoPlayerComponent(
            videoRenderer: videoPlayer.videoRenderer
        )

        // Create entity
        let entity = Entity()
        entity.name = Self.entityName
        entity.components.set(videoPlayerComponent)

        // Set stable position and scale
        entity.position = Self.entityPosition
        entity.scale = Self.entityScale

        logger.info("Raw stream entity configured:")
        logger.info("   Position: \(entity.position)")
        logger.info("   Scale: \(entity.scale)")

        return entity
    }

    /// Log entity creation
    private func logEntityCreated(_ entity: Entity) {
        logger.info("Raw stream entity created")
        logger.info("   Entity name: \(entity.name)")
        logger.info("   Mode: \(receiver.currentViewMode.rawValue)")
    }
}

// MARK: - Preview

@MainActor
private struct RawStreamView_PreviewWrapper: View {
    @StateObject private var mockPipeline: EndoscopeRenderPipeline
    @StateObject private var mockReceiver: WebRTCReceiver

    init() {
        let pipeline = EndoscopeRenderPipeline()
        _mockPipeline = StateObject(wrappedValue: pipeline)

        _mockReceiver = StateObject(
            wrappedValue: WebRTCReceiver(renderPipeline: pipeline)
        )
    }

    var body: some View {
        RawStreamView(
            receiver: mockReceiver,
            pipeline: mockPipeline
        )
        .onAppear {
            // Set mock frame size to default: full1080 (3840×1080)
            mockReceiver.currentFrameSize = CGSize(width: 3840, height: 1080)
            mockPipeline.configure(for: .rawStream)
        }
    }
}

#Preview {
    RawStreamView_PreviewWrapper()
}
