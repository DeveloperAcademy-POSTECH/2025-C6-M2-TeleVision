//
//  FileDemo2DView.swift
//  Hippo
//
//  2D file demo view using AVPlayer + VideoMaterial
//  Plays demo-2d.mp4 as a flat 2D plane (no SBS split, no stereo)
//

import SwiftUI
import RealityKit
import AVFoundation
import AVKit
import os.log

/// 2D file demo view - plays demo-2d.mp4 using AVPlayer and VideoMaterial
/// This is the default demo mode, showing video on a flat plane
struct FileDemo2DView: View {
    private let logger = Logger(
        subsystem: "com.television.hippo",
        category: "FileDemo2DView"
    )

    // AVPlayer for video playback
    @State private var player: AVPlayer?

    // Looping observer
    @State private var loopObserver: NSObjectProtocol?

    // Entity name for tracking
    private static let entityName = "2d-video-entity"

    var body: some View {
        #if os(visionOS)
        RealityView { content in
            logger.info("FileDemo2DView: Creating RealityView for 2D demo")

            // Get video URL from bundle
            guard let videoURL = Bundle.main.url(forResource: "demo-2d", withExtension: "mp4") else {
                logger.error("❌ demo-2d.mp4 not found in bundle")
                return
            }

            logger.info("   Video URL: \(videoURL.lastPathComponent)")

            // Create AVPlayer
            let avPlayer = AVPlayer(url: videoURL)
            avPlayer.actionAtItemEnd = .none  // Don't stop at end (we'll loop manually)

            // Create VideoMaterial with AVPlayer
            let material = VideoMaterial(avPlayer: avPlayer)

            // Create plane entity with 16:9 aspect ratio
            // Size tuned for comfortable viewing in Vision Pro
            let planeWidth: Float = 1.6
            let planeHeight: Float = 0.9  // 16:9 aspect ratio
            let planeMesh = MeshResource.generatePlane(width: planeWidth, height: planeHeight)

            let planeEntity = ModelEntity(mesh: planeMesh, materials: [material])
            planeEntity.name = Self.entityName
            planeEntity.position = SIMD3<Float>(0, 0, 0)  // Centered at origin

            content.add(planeEntity)

            // Start playback
            avPlayer.play()

            logger.info("✅ FileDemo2DView: 2D video playback started")
            logger.info("   Plane size: \(planeWidth) × \(planeHeight)")
            logger.info("   Position: \(planeEntity.position)")

            // Store player reference for cleanup
            Task { @MainActor in
                self.player = avPlayer
                setupLooping(player: avPlayer)
            }

        } update: { _ in
            // No update needed for simple 2D playback
        }
        .frame(depth: 0)
        .onAppear {
            logger.info("FileDemo2DView appeared")
        }
        .onDisappear {
            logger.info("FileDemo2DView disappeared - cleaning up")
            cleanup()
        }
        #else
        Color.black
            .overlay(
                Text("2D Video playback requires visionOS")
                    .foregroundColor(.white)
            )
        #endif
    }

    // MARK: - Private Methods

    /// Setup looping playback
    private func setupLooping(player: AVPlayer) {
        // Remove existing observer if any
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Add observer for end of playback
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            logger.debug("🔄 Video ended - looping back to start")
            player?.seek(to: .zero)
            player?.play()
        }

        logger.info("   Loop observer configured")
    }

    /// Cleanup resources
    private func cleanup() {
        // Remove loop observer
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
            loopObserver = nil
        }

        // Stop and release player
        player?.pause()
        player = nil

        logger.info("   Resources cleaned up")
    }
}

// MARK: - Preview

#Preview {
    FileDemo2DView()
}
