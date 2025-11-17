//
//  Stereo3DView.swift
//  Hippo
//
//  Stage 3: Stereo 3D view using VideoPlayerComponent
//  Production mode for clinical use with true stereo depth perception
//

import SwiftUI
import RealityKit
import AVFoundation
import os.log

/// Stage 3: Stereo 3D View (Production Mode)
/// Uses VideoPlayerComponent for true stereoscopic rendering
struct Stereo3DView: View {
    // Only observe receiver (pipeline is accessed via receiver)
    @ObservedObject var receiver: WebRTCReceiver

    // Pipeline reference (no observation needed, just access)
    let pipeline: EndoscopeRenderPipeline

    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "Stereo3DView"
    )

    // Constants
    private static let entityName = "stereo-video-entity"
    private static let baseHeight: Float = 1.35  // meters
    private static let minWidth: Float = 1.0     // meters (minimum)
    private static let maxWidth: Float = 3.0     // meters (maximum)
    private static let defaultWidth: Float = 2.4 // meters (16:9 default)

    /// Calculate plane scale based on frame size
    /// Maintains aspect ratio with width clamping for safety
    private var planeScale: SIMD3<Float> {
        let frameSize = receiver.currentFrameSize

        guard frameSize.width > 0, frameSize.height > 0 else {
            // Default scale (16:9 aspect ratio: 2.4m × 1.35m)
            return SIMD3(
                x: Self.defaultWidth,
                y: Self.baseHeight,
                z: 1.0
            )
        }

        // Calculate aspect ratio
        let aspectRatio = Float(frameSize.width) / Float(frameSize.height)

        // Width adjusted to maintain aspect ratio
        var calculatedWidth = Self.baseHeight * aspectRatio

        // Clamp width to safe range (1.0m ~ 3.0m)
        calculatedWidth = max(
            Self.minWidth,
            min(Self.maxWidth, calculatedWidth)
        )

        return SIMD3(
            x: calculatedWidth,
            y: Self.baseHeight,
            z: 1.0
        )
    }

    // MARK: - Body

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            logRendererStatus()

            // 1) 엔티티 생성 & 추가
            let entity = makeStereoEntity()
            content.add(entity)
            logEntityCreated(entity)

        } update: { content in
            // 2) frameSize 변경 시 scale 업데이트
            updateStereoEntityScale(in: content)

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
                Text("Stereo 3D requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }

    // MARK: - Setup Helpers

    /// RealityView가 처음 생성될 때 렌더러 상태 로그
    private func logRendererStatus() {
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

    /// VideoPlayerComponent + Entity 생성
    /// Architecture: HEVC → I420 → AVSampleBufferVideoRenderer → VideoPlayerComponent → Entity
    private func makeStereoEntity() -> Entity {
        // Get VideoPlayer directly from pipeline (guaranteed to exist in stereo3D mode)
        guard let videoPlayer = pipeline.getVideoRenderer() else {
            logger.error("CRITICAL: VideoPlayer not found in pipeline!")
            logger.error("   This should never happen in Stereo 3D mode")
            logger.error("   Creating empty entity as fallback")

            let entity = Entity()
            entity.name = Self.entityName
            return entity
        }

        logger.info("Creating VideoPlayerComponent with AVSampleBufferVideoRenderer")
        logger.info("   Renderer: \(videoPlayer.videoRenderer)")
        logger.info("   Renderer status: \(videoPlayer.videoRenderer.status.rawValue)")

        // Create VideoPlayerComponent with AVSampleBufferVideoRenderer
        // This is the only component needed - no AVPlayer, no VideoMaterial
        let videoPlayerComponent = VideoPlayerComponent(
            videoRenderer: videoPlayer.videoRenderer
        )

        logger.info("VideoPlayerComponent created successfully")

        // Create entity with VideoPlayerComponent only
        let entity = Entity()
        entity.name = Self.entityName
        entity.components.set(videoPlayerComponent)

        // Position: 2 meters in front of user
        entity.position = SIMD3<Float>(0, 0, -2.0)

        // Scale: Based on frame size (dynamically calculated)
        entity.scale = planeScale

        logger.info("Stereo3D entity configured:")
        logger.info("   Position: \(entity.position)")
        logger.info("   Scale: \(entity.scale)")

        return entity
    }

    /// Entity 생성 로그
    private func logEntityCreated(_ entity: Entity) {
        logger.info("Stereo3D VideoPlayerComponent created")
        logger.info("   Entity name: \(entity.name)")
        logger.info("   Position: \(entity.position)")
        logger.info("   Scale: \(entity.scale)")
    }

    /// frameSize 변경 시 RealityKit 엔티티 scale 업데이트
    private func updateStereoEntityScale(in content: RealityViewContent) {
        guard let entity = content.entities.first(where: { $0.name == Self.entityName }) else {
            logger.debug("Could not find video entity for scale update")
            return
        }

        let newScale = planeScale

        if entity.scale != newScale {
            entity.scale = newScale
            logger.info("Stereo3D scale updated: \(newScale)")
        }
    }

    // MARK: - Debug Monitoring

    #if DEBUG
    /// Monitor renderer status for debugging (DEBUG builds only)
    /// TODO: Remove this after stereo rendering is stable
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
        // @MainActor 컨텍스트에서 파이프라인 생성
        let pipeline = EndoscopeRenderPipeline()
        _mockPipeline = StateObject(wrappedValue: pipeline)

        // DI 패턴으로 파이프라인을 주입한 Receiver 생성
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
            // Set mock frame size (1920×1080, typical Full HD)
            mockReceiver.currentFrameSize = CGSize(width: 1920, height: 1080)
            mockPipeline.configure(for: .stereo3D)
        }
    }
}

#Preview {
    Stereo3DView_PreviewWrapper()
}
