//
//  Stereo3DView.swift
//  Hippo
//
//  Unified VideoPlayer view for all 3 rendering modes
//  - Raw SBS: Full SBS displayed (3840×1080 or 1920×540)
//  - Left-only Mono: Left eye only (1920×1080 or 960×540, safest for OR)
//  - Stereo 3D: True stereoscopic rendering
//

import SwiftUI
import RealityKit
import AVFoundation
import os.log

/// Unified view for all VideoPlayer-based rendering modes
struct Stereo3DView: View {
    // Only observe receiver (pipeline is accessed via receiver)
    @ObservedObject var receiver: WebRTCReceiver

    // Pipeline reference (no observation needed, just access)
    let pipeline: EndoscopeRenderPipeline

    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "Stereo3DView"
    )

    // Constants for stable positioning
    private static let entityName = "video-player-entity"
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
            // No dynamic updates needed for OR demo
        }
        .frame(depth: 0)  // RealityView origin on window plane
        .onAppear {
            logger.info("Stereo3DView appeared")
            logger.info("   Current mode: \(receiver.currentViewMode.rawValue)")

            #if DEBUG
            startDebugMonitoring()
            #endif
        }
        .onDisappear {
            logger.info("Stereo3DView disappeared")
        }
        #else
        Color.black
            .overlay(
                Text("VideoPlayer rendering requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }

    // MARK: - Setup Helpers

    /// Log renderer status at setup
    private func logSetup() {
        logger.info("Stereo3DView: Creating RealityView")

        // Get renderer directly from pipeline
        if let videoPlayer = pipeline.getVideoRenderer() {
            let renderer = videoPlayer.videoRenderer
            logger.info("   VideoPlayer available: YES")
            logger.info("   Renderer status: \(renderer.status.rawValue) (0=unknown, 1=ready, 2=failed)")
            logger.info("   Ready for more data: \(renderer.isReadyForMoreMediaData)")

            // Check if renderer has any error
            if renderer.status == .failed {
                if let error = renderer.error {
                    logger.error("   Renderer error: \(error.localizedDescription)")
                }
            }
        } else {
            logger.error("   VideoPlayer available: NO - this will cause rendering failure!")
        }

        logger.info("   Current frame size: \(Int(receiver.currentFrameSize.width))×\(Int(receiver.currentFrameSize.height))")
    }

    /// Create VideoPlayerComponent entity with stable position and scale
    private func makeVideoPlayerEntity() -> Entity {
        // Get VideoPlayer directly from pipeline
        guard let videoPlayer = pipeline.getVideoRenderer() else {
            logger.error("CRITICAL: VideoPlayer not found in pipeline!")
            logger.error("   This should never happen - pipeline should initialize VideoPlayer")
            logger.error("   Creating empty entity as fallback")

            let entity = Entity()
            entity.name = Self.entityName
            return entity
        }

        logger.info("Creating VideoPlayerComponent with AVSampleBufferVideoRenderer")
        logger.info("   Renderer: \(videoPlayer.videoRenderer)")
        logger.info("   Renderer status: \(videoPlayer.videoRenderer.status.rawValue)")

        // Create VideoPlayerComponent with AVSampleBufferVideoRenderer
        let videoPlayerComponent = VideoPlayerComponent(
            videoRenderer: videoPlayer.videoRenderer
        )

        logger.info("VideoPlayerComponent created successfully")

        // Create entity with VideoPlayerComponent
        let entity = Entity()
        entity.name = Self.entityName
        entity.components.set(videoPlayerComponent)

        // Set stable position and scale for OR demo
        entity.position = Self.entityPosition
        entity.scale = Self.entityScale

        logger.info("VideoPlayer entity configured:")
        logger.info("   Position: \(entity.position)")
        logger.info("   Scale: \(entity.scale)")

        return entity
    }

    /// Log entity creation
    private func logEntityCreated(_ entity: Entity) {
        logger.info("VideoPlayer entity created")
        logger.info("   Entity name: \(entity.name)")
        logger.info("   Position: \(entity.position)")
        logger.info("   Scale: \(entity.scale)")
        logger.info("   Mode: \(receiver.currentViewMode.rawValue)")
    }

    // MARK: - Debug Monitoring

    #if DEBUG
    /// Monitor renderer status for debugging (DEBUG builds only)
    private func startDebugMonitoring() {
        Task {
            logger.debug("Starting debug monitoring (10 seconds)...")

            for i in 0..<10 {
                try? await Task.sleep(for: .seconds(1))

                // Get renderer directly from pipeline
                guard let videoPlayer = pipeline.getVideoRenderer() else {
                    logger.error("[Debug \(i+1)/10] VideoPlayer not available")
                    continue
                }

                let status = videoPlayer.videoRenderer.status
                let readyForData = videoPlayer.videoRenderer.isReadyForMoreMediaData

                if status == .failed {
                    logger.error("[Debug \(i+1)/10] Renderer status: FAILED")
                    if let error = videoPlayer.videoRenderer.error {
                        logger.error("[Debug \(i+1)/10] Error: \(error.localizedDescription)")
                    }
                } else if !readyForData {
                    logger.warning("[Debug \(i+1)/10] Renderer not ready for data")
                } else {
                    logger.debug("[Debug \(i+1)/10] Renderer OK, status: \(status.rawValue)")
                }
            }

            logger.debug("Debug monitoring complete")
        }
    }
    #endif
}

// MARK: - Preview

@MainActor
private struct Stereo3DView_PreviewWrapper: View {
    @StateObject private var mockPipeline: EndoscopeRenderPipeline
    @StateObject private var mockReceiver: WebRTCReceiver

    init() {
        // @MainActor context에서 pipeline 생성
        let pipeline = EndoscopeRenderPipeline()
        _mockPipeline = StateObject(wrappedValue: pipeline)

        // DI pattern으로 pipeline을 주입한 Receiver 생성
        _mockReceiver = StateObject(
            wrappedValue: WebRTCReceiver(renderPipeline: pipeline)
        )
    }

    var body: some View {
        Stereo3DView(
            receiver: mockReceiver,
            pipeline: mockPipeline
        )
        .onAppear {
            // Set mock frame size to default: full1080 (3840×1080)
            // This matches PipelineConfigurationManager default: SBSMode.full1080
            mockReceiver.currentFrameSize = CGSize(width: 3840, height: 1080)
            mockPipeline.configure(for: .stereo3D)
        }
    }
}

#Preview {
    Stereo3DView_PreviewWrapper()
}
