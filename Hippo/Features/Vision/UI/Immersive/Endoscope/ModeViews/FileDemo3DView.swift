//
//  FileDemo3DView.swift
//  Hippo
//
//  3D file demo view - separate from WebRTC Stereo3DView
//

import SwiftUI
import RealityKit
import os.log

/// 3D 파일 데모 전용 뷰
struct FileDemo3DView: View {
    let pipeline: EndoscopeRenderPipeline

    private let logger = Logger(subsystem: "com.television.hippo", category: "FileDemo3DView")

    private static let entityName = "demo-3d-video-entity"
    private static let entityScale = SIMD3<Float>(0.4, 0.4, 0.4)

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            logger.info("FileDemo3DView: RealityView make closure called")
            content.add(makeEntity())
        } update: { content in
            tryAttachVideoPlayer(to: content)
        }
        .frame(depth: 0)
        .onAppear {
            logger.info("FileDemo3DView: onAppear")
        }
        .onDisappear {
            logger.info("FileDemo3DView: onDisappear")
        }
        #else
        Color.black.overlay(Text("3D Demo requires visionOS").foregroundColor(.white))
        #endif
    }

    // MARK: - Private Methods

    private func makeEntity() -> Entity {
        let entity = Entity()
        entity.name = Self.entityName
        entity.scale = Self.entityScale
        attachVideoPlayerIfReady(to: entity)
        logger.info("FileDemo3DView: Entity created (scale: 0.4)")
        return entity
    }

    private func attachVideoPlayerIfReady(to entity: Entity) {
        guard let videoPlayer = pipeline.getVideoRenderer() else { return }
        entity.components.set(VideoPlayerComponent(videoRenderer: videoPlayer.videoRenderer))
    }

    private func tryAttachVideoPlayer(to content: RealityViewContent) {
        guard let entity = content.entities.first(where: { $0.name == Self.entityName }),
              entity.components[VideoPlayerComponent.self] == nil,
              let videoPlayer = pipeline.getVideoRenderer() else { return }

        entity.components.set(VideoPlayerComponent(videoRenderer: videoPlayer.videoRenderer))
        logger.info("FileDemo3DView: VideoPlayer attached (late)")
    }
}
