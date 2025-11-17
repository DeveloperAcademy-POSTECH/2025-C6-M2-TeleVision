//
//  SplitSBSView.swift
//  Hippo
//
//  Stage 2: Left-only Mono view (OR minimum success line)
//  Displays left eye only for safe 2D viewing in OR
//

import SwiftUI
import RealityKit
import AVFoundation
import os.log

/// Stage 2: Split SBS View (Left-only Mono for OR)
/// Extracts and displays left eye only (1920×1080 or 960×540)
struct SplitSBSView: View {
    // Only observe receiver (pipeline is accessed via receiver)
    @ObservedObject var receiver: WebRTCReceiver

    // Pipeline reference (no observation needed, just access)
    let pipeline: EndoscopeRenderPipeline

    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "SplitSBSView"
    )

    // Constants for stable positioning (same as Stereo3DView)
    private static let entityName = "split-video-entity"
    private static let entityPosition = SIMD3<Float>.zero  // Default position
    private static let entityScale = SIMD3<Float>(0.2, 0.2, 0.2)  // Original size

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
            logger.info("SplitSBSView appeared")
            logger.info("   Current mode: \(receiver.currentViewMode.rawValue)")
        }
        .onDisappear {
            logger.info("SplitSBSView disappeared")
        }
        #else
        Color.black
            .overlay(
                Text("Split SBS view requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }

    // MARK: - Setup Helpers

    /// Log renderer status at setup
    private func logSetup() {
        logger.info("SplitSBSView: Creating RealityView")

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

        logger.info("Split SBS entity configured:")
        logger.info("   Position: \(entity.position)")
        logger.info("   Scale: \(entity.scale)")

        return entity
    }

    /// Log entity creation
    private func logEntityCreated(_ entity: Entity) {
        logger.info("Split SBS entity created")
        logger.info("   Entity name: \(entity.name)")
        logger.info("   Mode: \(receiver.currentViewMode.rawValue)")
    }
}

// MARK: - Preview

@MainActor
private struct SplitSBSView_PreviewWrapper: View {
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
        SplitSBSView(
            receiver: mockReceiver,
            pipeline: mockPipeline
        )
        .onAppear {
            // Set mock frame size to default: full1080 (3840×1080)
            mockReceiver.currentFrameSize = CGSize(width: 3840, height: 1080)
            mockPipeline.configure(for: .splitSBS)
        }
    }
}

#Preview {
    SplitSBSView_PreviewWrapper()
}
